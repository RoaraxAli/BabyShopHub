require("dotenv").config();
const express = require("express");
const cors = require("cors");
const nodemailer = require("nodemailer");

const app = express();

// Enable CORS so your Flutter Web application can call this API directly
app.use(cors());
app.use(express.json());

const emailUser = process.env.EMAIL_USER;
const emailPass = process.env.EMAIL_PASS;

const transporter = nodemailer.createTransport({
  host: "smtp.zoho.com",
  port: 587,
  secure: false,
  auth: {
    user: emailUser,
    pass: emailPass,
  },
});

app.post("/send-email", async (req, res) => {
  const { to, subject, html } = req.body;

  if (!to || !subject || !html) {
    return res.status(400).json({ error: "Missing required fields (to, subject, html)" });
  }

  const mailOptions = {
    from: `"BabyShopHub" <${emailUser}>`,
    to: to,
    subject: subject,
    html: html,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log(`[SUCCESS] Email dispatched to ${to}: ${info.messageId}`);
    return res.status(200).json({ message: "Email sent successfully", messageId: info.messageId });
  } catch (error) {
    console.error("[FAILURE] SMTP Error:", error);
    return res.status(500).json({ error: "Failed to send email through SMTP", details: error.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`SMTP Relay Server is active on port ${PORT}`);
});
