import React from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";

type AppRouterProps = {
  app: React.ReactElement;
  downloads: React.ReactElement;
  handoff: React.ReactElement;
  run: React.ReactElement;
};

export function AppRouter({ app, downloads, handoff, run }: AppRouterProps) {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={app} />
        <Route path="/downloads/*" element={downloads} />
        <Route path="/handoff/*" element={handoff} />
        <Route path="/run/*" element={run} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
