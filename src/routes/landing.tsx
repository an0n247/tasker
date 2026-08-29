import { createFileRoute } from "@tanstack/react-router";
import LandingPage from "./index";

export const Route = createFileRoute("/landing")({
  head: () => ({
    meta: [
      { title: "Noble Gain – Earn Rewards for Everyday Tasks" },
      {
        name: "description",
        content:
          "Noble Gain is a gamified rewards platform. Complete tasks, earn points, and redeem them for real rewards.",
      },
      { property: "og:type", content: "website" },
      { property: "og:title", content: "Noble Gain – Earn Rewards for Everyday Tasks" },
      {
        property: "og:description",
        content: "Complete tasks, earn points, and redeem them for real rewards on Noble Gain.",
      },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: RouteComponent,
});

function RouteComponent() {
  return <LandingPage />;
}
