import React from "react";
import ReactDOM from "react-dom/client";

import { App } from "./app/app";
import { AuthProvider } from "./lib/auth";
import { NotificationProvider } from "./lib/notifications";
import { PwaProvider } from "./lib/pwa";
import "./styles/global.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <NotificationProvider>
      <PwaProvider>
        <AuthProvider>
          <App />
        </AuthProvider>
      </PwaProvider>
    </NotificationProvider>
  </React.StrictMode>,
);
