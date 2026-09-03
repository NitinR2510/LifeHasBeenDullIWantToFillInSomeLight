const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MAX_GOAL_LENGTH = 600;
const difficulties = new Set(["easy", "medium", "hard"]);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isValidRequest(value: unknown): value is {
  goal: string;
  topic: string;
  difficulty: string;
  theme: string;
} {
  if (!value || typeof value !== "object") return false;
  const request = value as Record<string, unknown>;
  return typeof request.goal === "string"
    && request.goal.trim().length > 0
    && request.goal.length <= MAX_GOAL_LENGTH
    && typeof request.topic === "string"
    && request.topic.trim().length > 0
    && request.topic.length <= 100
    && typeof request.theme === "string"
    && request.theme.length <= 30
    && typeof request.difficulty === "string"
    && difficulties.has(request.difficulty);
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  let input: unknown;
  try {
    input = await request.json();
  } catch {
    return json({ error: "Request body must be JSON" }, 400);
  }
  if (!isValidRequest(input)) return json({ error: "Invalid goal plan request" }, 400);

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    console.error("OPENAI_API_KEY is not configured");
    return json({ error: "Plan generation is unavailable" }, 503);
  }

  const prompt = [
    "Create a practical, tailored action plan for the goal below.",
    "Return 3 to 7 steps. Each step must be a specific, concise action.",
    "Match the difficulty: easy = one small session; medium = several sessions this week; hard = a structured week-long effort.",
    "Do not repeat the goal, add a preamble, make medical/legal/financial claims, or include markdown.",
    `Topic: ${input.topic.trim()}`,
    `Difficulty: ${input.difficulty}`,
    `Goal: ${input.goal.trim()}`,
  ].join("\n");

  try {
    const openAIResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_MODEL") || "gpt-5-mini",
        input: prompt,
        text: {
          format: {
            type: "json_schema",
            name: "goal_plan",
            strict: true,
            schema: {
              type: "object",
              additionalProperties: false,
              required: ["steps"],
              properties: {
                steps: {
                  type: "array",
                  minItems: 3,
                  maxItems: 7,
                  items: { type: "string", minLength: 1, maxLength: 240 },
                },
              },
            },
          },
        },
      }),
    });
    if (!openAIResponse.ok) {
      console.error("OpenAI request failed:", openAIResponse.status);
      return json({ error: "Plan generation is unavailable" }, 502);
    }

    const result = await openAIResponse.json();
    const text = result.output_text;
    const plan = typeof text === "string" ? JSON.parse(text) : null;
    if (!Array.isArray(plan?.steps) || plan.steps.length < 3 || plan.steps.length > 7
      || !plan.steps.every((step: unknown) => typeof step === "string" && step.trim().length > 0 && step.length <= 240)) {
      throw new Error("OpenAI returned an invalid plan");
    }

    return json({ steps: plan.steps.map((step: string) => step.trim()) });
  } catch (error) {
    console.error("Plan generation failed:", error instanceof Error ? error.message : error);
    return json({ error: "Plan generation is unavailable" }, 502);
  }
});
