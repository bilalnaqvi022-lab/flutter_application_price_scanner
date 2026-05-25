**Screenshots**
<p align="center">
  <img src="https://github.com/user-attachments/assets/036fb155-bffe-4722-b89b-1449567a5375" width="220" hspace="10"/>

  <img src="https://github.com/user-attachments/assets/348cd9a8-95eb-45ab-a649-711dd0b46b26" width="220" hspace="10"/>

  <img src="https://github.com/user-attachments/assets/698d53e1-249b-42a8-aa47-c163b6e188ee" width="220" hspace="10"/>
</p>

<br/>

<p align="center">
  <img src="https://github.com/user-attachments/assets/492d460a-b983-4f6d-b0e9-4b0305d395ca" width="220" hspace="10"/>

  <img src="https://github.com/user-attachments/assets/9463b2f9-f5b8-4f30-91dd-a74ff97694b5" width="220" hspace="10"/>

  <img src="https://github.com/user-attachments/assets/39b587b7-d097-4caa-b893-b5e1f380d2df" width="220" hspace="10"/>
</p>


PriceLens– Local Market Price Comparison App

The Local Market Price Comparison App is a mobile application that allows users to 
compare prices of products across local shops and online stores. By scanning product 
barcodes or QR codes, users can instantly see price differences and find the cheapest 
option available. The app integrates with local shop databases, online marketplaces, and 
APIs to provide real-time price comparisons, helping consumers save money and make 
informed purchasing decisions.

Functional Requirements
• User Input: Scan barcodes or QR codes of products via the app camera.
• Price Comparison: Fetch prices from local shop databases and online 
marketplaces.
• Cheapest Option Alert: Highlight the cheapest price and suggest purchase location.
• History Section: Save scanned products for future reference.
• Notifications: Optional alerts when a product’s price drops.
• User-Friendly Interface: Simple navigation for all age groups.
Non-Functional Requirements
• Performance: Price results should appear within 2–5 seconds.
• Accuracy: Prices must be up-to-date and verified via APIs or shop inputs.
• Usability: Intuitive interface suitable for everyday users.
• Scalability: Should support multiple users and large product databases.
• Security & Privacy: User data encrypted; personal data not shared without 
consent.
• Reliability: App must function consistently without crashes.
• Maintainability: Databases and APIs should be updatable as markets change.
4 Full Screens via Bottom Navigation:

🏠 Home — Hero banner, stat cards (scans today, money saved, live stores), quick action grid, recent scans, and top savings tips
📷 Scanner — Animated scan viewport with moving laser line, corner bracket overlay, grid background, loading state with "Fetching prices…", and a manual barcode entry dialog
📊 Results — Product header, "Best Price" champion banner with savings callout, animated price range bar, ranked store list with online/local badges & ratings, and Share / Set Alert buttons
🔔 Notifications — Toggle switches for Price Drops, Weekly Report & Flash Deals, plus a styled notification feed with unread indicators

Core Functionality

mobile_scanner — barcode/QR scanning via device camera
http — API calls to fetch live prices from stores
shared_preferences + sqflite — persist scan history locally

UI & Experience

google_fonts + Poppins font family — polished typography
flutter_animate — smooth animations and transitions
lottie — JSON-based animations for loading/success states
shimmer — skeleton loading placeholders while prices fetch

App Features

provider — state management across screens
flutter_local_notifications — price drop push alerts
share_plus — share product comparisons
url_launcher — open store links (Daraz, Carrefour, etc.)
connectivity_plus — detect offline mode gracefully
cached_network_image — cache store logos/product images
intl — format PKR currency and dates correctly


