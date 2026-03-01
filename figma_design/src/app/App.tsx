import { RouterProvider } from "react-router";
import { router } from "./routes";
import { BarProvider } from "./context/BarContext";

export default function App() {
  return (
    <BarProvider>
      <RouterProvider router={router} />
    </BarProvider>
  );
}
