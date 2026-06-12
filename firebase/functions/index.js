const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
require("dotenv").config();

admin.initializeApp();
const db = admin.firestore();

const emailUser = process.env.EMAIL_USER;
const emailPass = process.env.EMAIL_PASS;

if (!emailUser || !emailPass) {
  functions.logger.error("CRITICAL CONFIGURATION ERROR: EMAIL_USER and EMAIL_PASS environment variables must be defined inside the .env file.");
}

// SMTP Transport setup using credentials loaded from process env (Zoho SMTP)
const transporter = nodemailer.createTransport({
  host: "smtp.zoho.com",
  port: 465,
  secure: true, // use SSL
  auth: {
    user: emailUser,
    pass: emailPass,
  },
});

// Helper: Sends HTML Email safely
async function sendMail(to, subject, htmlContent) {
  if (!emailUser) {
    functions.logger.error("SMTP Mail aborted: EMAIL_USER is not configured in environment variables.");
    return false;
  }

  const mailOptions = {
    from: `"BabyShopHub" <${emailUser}>`,
    to: to,
    subject: subject,
    html: htmlContent,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    functions.logger.log(`Email successfully dispatched: ${info.messageId}`);
    return true;
  } catch (error) {
    functions.logger.error("Failed to send email through SMTP:", error);
    return false;
  }
}


/**
 * 1. welcome Email trigger
 * Triggers when a new parent profile is created in /users/{userId}
 */
exports.onUserCreated = functions.firestore
  .document("users/{userId}")
  .onCreate(async (snap, context) => {
    const userData = snap.data();
    const email = userData.email;
    const name = userData.displayName || "Valued Parent";

    if (!email) {
      functions.logger.warn("Skipping welcome email: profile lacks email field.");
      return null;
    }

    const htmlContent = `
      <div style="font-family: 'Inter', Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #f0f0f0; border-radius: 12px;">
        <h1 style="color: #FF9EAA; text-align: center;">Welcome to BabyShopHub! 👶</h1>
        <p>Dear <strong>${name}</strong>,</p>
        <p>Thank you so much for joining our family. We are thrilled to help you on your parenting journey with premium products designed for care, comfort, and joy.</p>
        <div style="background-color: #B0D9B1; background-opacity: 0.1; padding: 16px; border-radius: 8px; margin: 20px 0; text-align: center;">
          <p style="margin: 0; color: #2e7d32; font-weight: bold;">Your parent profile is active! 🎉</p>
        </div>
        <p>If you have any questions, you can open our interactive <strong>Grounded AI User Guide</strong> or contact our customer support desk.</p>
        <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
        <p style="font-size: 11px; color: #999; text-align: center;">This is an automated notification. Do not reply to this email.</p>
      </div>
    `;

    return sendMail(email, "Welcome to BabyShopHub! 👶", htmlContent);
  });

/**
 * 2. Checkout Success Email trigger
 * Triggers when a new order document is registered in /orders/{orderId}
 */
exports.onOrderCreated = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snap, context) => {
    const orderData = snap.data();
    const orderId = context.params.orderId;
    const email = orderData.email;
    const items = orderData.items || [];
    const total = orderData.total || 0;
    const address = orderData.address || "Simulated Delivery Address";

    if (!email) {
      functions.logger.warn("Skipping order receipt: invoice lacks email.");
      return null;
    }

    // Build invoice items table rows
    let itemsRows = "";
    items.forEach((item) => {
      itemsRows += `
        <tr>
          <td style="padding: 8px; border-bottom: 1px solid #eee;">${item.name} (x${item.quantity})</td>
          <td style="padding: 8px; border-bottom: 1px solid #eee; text-align: right;">$${(item.price * item.quantity).toFixed(2)}</td>
        </tr>
      `;
    });

    const htmlContent = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 12px;">
        <h2 style="color: #FF9EAA; text-align: center;">Your Order is Confirmed! 🚚</h2>
        <p>Order ID: <strong>#${orderId}</strong></p>
        <p>Thank you for your purchase. We are preparing your baby products with love and care.</p>
        
        <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
          <thead>
            <tr style="background-color: #f7f7f7;">
              <th style="padding: 8px; text-align: left; border-bottom: 2px solid #ddd;">Product Item</th>
              <th style="padding: 8px; text-align: right; border-bottom: 2px solid #ddd;">Total</th>
            </tr>
          </thead>
          <tbody>
            ${itemsRows}
          </tbody>
          <tfoot>
            <tr>
              <td style="padding: 8px; font-weight: bold;">Grand Total:</td>
              <td style="padding: 8px; font-weight: bold; text-align: right; color: #FF9EAA;">$${total.toFixed(2)}</td>
            </tr>
          </tfoot>
        </table>

        <div style="background-color: #f9f9f9; padding: 12px; border-radius: 8px; margin-top: 16px;">
          <p style="margin: 0; font-size: 13px;"><strong>Delivery Shipping Address:</strong><br/>${address}</p>
        </div>
        <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
        <p style="font-size: 11px; color: #999; text-align: center;">Need to change address? Promptly ask support or review return policies.</p>
      </div>
    `;

    return sendMail(email, `Receipt for Order #${orderId.substring(0, 8)}`, htmlContent);
  });

/**
 * 3. Wishlist Back-in-Stock Alert trigger
 * Triggers when a product document in /products/{productId} is restocked
 */
exports.onProductStockUpdated = functions.firestore
  .document("products/{productId}")
  .onUpdate(async (change, context) => {
    const previousData = change.before.data();
    const newData = change.after.data();
    const productId = context.params.productId;

    // Check if transition matches Out-of-Stock (0) to In-Stock (> 0)
    if (previousData.stock === 0 && newData.stock > 0) {
      functions.logger.log(`Product ${newData.name} restocked from 0 to ${newData.stock}. Searching wishlists.`);

      // Query wishlists collection for users who bookmark this item
      const wishlistsSnap = await db
        .collection("wishlists")
        .where("productId", "==", productId)
        .get();

      if (wishlistsSnap.empty) {
        functions.logger.log("No parents wishlisted this restocked item.");
        return null;
      }

      const alertPromises = [];

      wishlistsSnap.forEach((doc) => {
        const wishlistData = doc.data();
        const email = wishlistData.userEmail;

        if (email) {
          const htmlContent = `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #f0f0f0; border-radius: 12px;">
              <h2 style="color: #FF9EAA; text-align: center;">Good News! Restock Alert 🥳</h2>
              <p>Hello parent,</p>
              <p>You asked to be notified! We are excited to announce that your wishlisted item is now back in stock:</p>
              
              <div style="border: 1px solid #eee; border-radius: 8px; padding: 12px; display: flex; align-items: center; margin: 20px 0;">
                <div>
                  <h3 style="margin: 0; color: #333;">${newData.name}</h3>
                  <p style="margin: 4px 0 0 0; font-size: 14px; font-weight: bold; color: #FF9EAA;">$${newData.price.toFixed(2)}</p>
                  <p style="margin: 8px 0 0 0; font-size: 12px; color: #2e7d32; font-weight: bold;">Only ${newData.stock} items left in stock!</p>
                </div>
              </div>

              <p style="text-align: center; margin: 24px 0;">
                <a href="#" style="background-color: #FF9EAA; color: white; padding: 12px 24px; text-decoration: none; border-radius: 20px; font-weight: bold;">Buy It Now</a>
              </p>
              
              <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
              <p style="font-size: 11px; color: #999; text-align: center;">We send this because this product was in your active wishlist profile.</p>
            </div>
          `;

          alertPromises.push(
            sendMail(email, `Hurray! ${newData.name} is Back in Stock! 🍼`, htmlContent)
          );
        }
      });

      return Promise.all(alertPromises);
    }
    return null;
  });

/**
 * 4. Unknown Location Login Alert trigger
 * Triggers when a login threat warning document is registered in /logins/{loginId}
 */
exports.onLoginLocationCheck = functions.firestore
  .document("logins/{loginId}")
  .onCreate(async (snap, context) => {
    const loginData = snap.data();
    const email = loginData.email;
    const location = loginData.location || "Unknown IP Area";
    const device = loginData.device || "Unknown Web Device";
    const time = loginData.time || new Date().toLocaleString();

    if (!email) {
      functions.logger.warn("Skipping location warning: login data lacks email.");
      return null;
    }

    const htmlContent = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #FFCDD2; border-radius: 12px;">
        <h2 style="color: #D32F2F; text-align: center;">⚠️ Security Alert: Login from New Location</h2>
        <p>Hello,</p>
        <p>We detected an unusual login action on your BabyShopHub account from a location you don't normally use.</p>
        
        <div style="background-color: #FFEBEE; border-left: 4px solid #D32F2F; padding: 12px; border-radius: 4px; margin: 20px 0;">
          <p style="margin: 0; font-size: 13px;"><strong>Location:</strong> ${location}</p>
          <p style="margin: 4px 0 0 0; font-size: 13px;"><strong>Device Browser:</strong> ${device}</p>
          <p style="margin: 4px 0 0 0; font-size: 13px;"><strong>Timestamp:</strong> ${time}</p>
        </div>

        <p><strong>Was this you?</strong> If yes, you can ignore this email. No action is required.</p>
        <p><strong>Not you?</strong> Please immediately log in to your account, reset your password, and ensure your <strong>Multi-Factor Authentication (MFA)</strong> is activated under settings.</p>
        
        <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
        <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Security Operations Center (SOC)</p>
      </div>
    `;

    return sendMail(email, "⚠️ Security Alert: Login from Unknown Location", htmlContent);
  });

/**
 * 5. Unified Mail Trigger Handler
 * Triggers when a new document is written to /mail_triggers/{triggerId}
 */
exports.onMailTriggerCreated = functions.firestore
  .document("mail_triggers/{triggerId}")
  .onCreate(async (snap, context) => {
    const triggerData = snap.data();
    const to = triggerData.to;
    const type = triggerData.type;
    const data = triggerData.data || {};

    if (!to) {
      functions.logger.warn("Skipping mail trigger: missing 'to' field.");
      return null;
    }

    let subject = "Notification from BabyShopHub";
    let htmlContent = "";

    if (type === "REGISTRATION_OTP") {
      subject = "Verify Your Email - BabyShopHub OTP";
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 12px;">
          <h2 style="color: #FF9EAA; text-align: center;">Verify Your Email Address</h2>
          <p>Hello,</p>
          <p>Thank you for registering at BabyShopHub. Please use the following One-Time Password (OTP) to verify your email address and complete registration:</p>
          <div style="background-color: #f7f7f7; padding: 16px; border-radius: 8px; margin: 20px 0; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #FF9EAA;">
            ${data.otp}
          </div>
          <p>This code will expire shortly. If you did not request this, you can ignore this email.</p>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Security Operations</p>
        </div>
      `;
    } else if (type === "PASSWORD_RESET_OTP") {
      subject = "Reset Your Password - BabyShopHub OTP";
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 12px;">
          <h2 style="color: #FF9EAA; text-align: center;">Reset Your Password</h2>
          <p>Hello,</p>
          <p>We received a request to reset your password. Use the following One-Time Password (OTP) to proceed:</p>
          <div style="background-color: #f7f7f7; padding: 16px; border-radius: 8px; margin: 20px 0; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #FF9EAA;">
            ${data.otp}
          </div>
          <p>If you did not request a password reset, please secure your account immediately.</p>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Security Operations</p>
        </div>
      `;
    } else if (type === "CHECKOUT_SUCCESS") {
      subject = "Order Confirmed - BabyShopHub";
      
      let itemsRows = "";
      if (Array.isArray(data.items)) {
        data.items.forEach((item) => {
          itemsRows += `
            <tr>
              <td style="padding: 8px; border-bottom: 1px solid #eee;">${item.name} (x${item.quantity})</td>
              <td style="padding: 8px; border-bottom: 1px solid #eee; text-align: right;">$${(item.price * item.quantity).toFixed(2)}</td>
            </tr>
          `;
        });
      }

      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 12px;">
          <h2 style="color: #FF9EAA; text-align: center;">Your Order is Confirmed</h2>
          <p>Thank you for your purchase. We are preparing your baby products with love and care.</p>
          
          <table style="width: 100%; border-collapse: collapse; margin: 20px 0;">
            <thead>
              <tr style="background-color: #f7f7f7;">
                <th style="padding: 8px; text-align: left; border-bottom: 2px solid #ddd;">Product Item</th>
                <th style="padding: 8px; text-align: right; border-bottom: 2px solid #ddd;">Total</th>
              </tr>
            </thead>
            <tbody>
              ${itemsRows}
            </tbody>
            <tfoot>
              <tr>
                <td style="padding: 8px; font-weight: bold;">Grand Total:</td>
                <td style="padding: 8px; font-weight: bold; text-align: right; color: #FF9EAA;">$${(data.total || 0).toFixed(2)}</td>
              </tr>
            </tfoot>
          </table>

          <div style="background-color: #f9f9f9; padding: 12px; border-radius: 8px; margin-top: 16px;">
            <p style="margin: 0; font-size: 13px;"><strong>Delivery Shipping Address:</strong><br/>${data.address || "Simulated Delivery Address"}</p>
          </div>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Logistics Division</p>
        </div>
      `;
    } else if (type === "WELCOME") {
      subject = "Welcome to BabyShopHub";
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 12px;">
          <h1 style="color: #FF9EAA; text-align: center;">Welcome to BabyShopHub</h1>
          <p>Dear <strong>${data.name || "Parent"}</strong>,</p>
          <p>Thank you so much for joining our family. We are thrilled to help you on your parenting journey with premium products designed for care, comfort, and joy.</p>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Family</p>
        </div>
      `;
    } else if (type === "LOGIN_NOTIFICATION") {
      subject = "Security Alert: Login Notification";
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #FFCDD2; border-radius: 12px;">
          <h2 style="color: #D32F2F; text-align: center;">Security Alert: New Login</h2>
          <p>Hello,</p>
          <p>We detected a new login action on your BabyShopHub account.</p>
          <div style="background-color: #FFEBEE; border-left: 4px solid #D32F2F; padding: 12px; border-radius: 4px; margin: 20px 0;">
            <p style="margin: 0; font-size: 13px;"><strong>Time:</strong> ${data.time}</p>
          </div>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Security Operations</p>
        </div>
      `;
    } else if (type === "WISHLIST_STOCK_ALERT") {
      subject = `Hurray! ${data.name} is Back in Stock!`;
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #f0f0f0; border-radius: 12px;">
          <h2 style="color: #FF9EAA; text-align: center;">Good News! Restock Alert</h2>
          <p>Hello parent,</p>
          <p>You asked to be notified! We are excited to announce that your wishlisted item is now back in stock:</p>
          <div style="border: 1px solid #eee; border-radius: 8px; padding: 12px; margin: 20px 0;">
            <h3 style="margin: 0; color: #333;">${data.name}</h3>
            <p style="margin: 4px 0 0 0; font-size: 14px; font-weight: bold; color: #FF9EAA;">$${(data.price || 0).toFixed(2)}</p>
            <p style="margin: 8px 0 0 0; font-size: 12px; color: #2e7d32; font-weight: bold;">Only ${data.stock} items left in stock!</p>
          </div>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Wishlist Support</p>
        </div>
      `;
    } else if (type === "SUPPORT_CONTACT") {
      subject = `Support Inquiry: ${data.subject}`;
      htmlContent = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 12px;">
          <h2 style="color: #FF9EAA; text-align: center;">New Support Request</h2>
          <p>You received a new inquiry from the BabyShopHub Contact Form:</p>
          <div style="background-color: #f9f9f9; padding: 16px; border-radius: 8px; margin: 20px 0;">
            <p><strong>Name:</strong> ${data.name}</p>
            <p><strong>Email:</strong> ${data.email}</p>
            <p><strong>Subject:</strong> ${data.subject}</p>
            <p style="margin-top: 12px; border-top: 1px solid #ddd; padding-top: 12px;"><strong>Message:</strong><br/>${data.message}</p>
          </div>
          <hr style="border: 0; border-top: 1px solid #eeeeee; margin: 20px 0;" />
          <p style="font-size: 11px; color: #999; text-align: center;">BabyShopHub Customer Support Team</p>
        </div>
      `;
    }

    return sendMail(to, subject, htmlContent);
  });
