import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro/zod";

const news = defineCollection({
  loader: glob({
    base: "./src/content/news",
    pattern: "**/*.{md,mdx}",
  }),
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    description: z.string(),
    categories: z.array(z.string()).default([]),
    tags: z.array(z.string()).default([]),
  }),
});

export const collections = { news };
