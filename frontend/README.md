# TinyURL Frontend

A modern React frontend for the TinyURL service, built with Vite and Tailwind CSS.

## Features

- ✅ Beautiful, responsive UI with Tailwind CSS
- ✅ URL shortening form
- ✅ Copy to clipboard functionality
- ✅ Error handling
- ✅ Loading states

## Prerequisites

- Node.js 18+ and npm
- Backend API Gateway running on `http://localhost:8080`

## Installation

```bash
# Install dependencies
npm install
```

## Development

```bash
# Start the development server
npm run dev
```

The app will be available at `http://localhost:5173` (or the next available port).

## Build for Production

```bash
# Build for production
npm run build

# Preview production build
npm run preview
```

## Usage

1. Make sure your backend services are running (API Gateway on port 8080)
2. Start the frontend: `npm run dev`
3. Open `http://localhost:5173` in your browser
4. Enter a long URL and click "Shorten URL"
5. Copy the generated short URL

## Project Structure

```
frontend/
├── src/
│   ├── App.jsx          # Main application component
│   ├── App.css          # Custom styles
│   ├── index.css        # Tailwind CSS imports
│   └── main.jsx         # Application entry point
├── index.html           # HTML template
├── tailwind.config.js   # Tailwind configuration
└── postcss.config.js    # PostCSS configuration
```

## API Integration

The frontend communicates with the API Gateway at `http://localhost:8080`:

- **Create Short URL**: `POST /api/v1/create/shorten`
  - Request body: `{ "originalUrl": "...", "baseUrl": "..." }`
  - Response: `{ "shortUrl": "...", "originalUrl": "..." }`
