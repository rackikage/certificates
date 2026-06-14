# Practice Questions — Prompt Engineering for ChatGPT

## Module 1: Course Introduction

**Q1.** What is a "prompt" in the context of large language models?
- A) A programming function
- B) A natural language instruction or question given to an LLM
- C) A database query
- D) A training dataset

**Answer: B** — A prompt is any text input to an LLM that shapes its response.

---

**Q2.** Why do large language models produce different outputs for the same prompt?
- A) They have bugs
- B) They use random sampling/temperature during text generation
- C) They are connected to live data
- D) They change their training data

**Answer: B** — LLMs use randomness (temperature) in token selection, causing varied outputs.

---

**Q3.** What makes an "expert user" of LLMs more productive than a beginner?
- A) They have faster internet
- B) They pay for premium access
- C) They understand how to write effective prompts
- D) They use more expensive models

**Answer: C** — Expert prompt writers unlock significantly more value from the same tools.

---

## Module 2: Introduction to Prompts

**Q4.** What is the Persona Pattern?
- A) Creating a user profile
- B) Telling the LLM to act as a specific role or expert
- C) Changing the LLM's name
- D) Training a custom model

**Answer: B** — "Act as a [persona]" directs the LLM to respond with that role's expertise and perspective.

---

**Q5.** What is a "root prompt"?
- A) The first prompt ever written
- B) A system-level prompt that sets persistent behavior for a conversation
- C) A prompt about trees
- D) The default prompt of the LLM

**Answer: B** — Root prompts establish context and rules that apply throughout the conversation.

---

**Q6.** Why does introducing new information in a prompt help?
- A) It speeds up the LLM
- B) It overrides the LLM's training data with relevant context it hasn't seen
- C) It reduces costs
- D) It makes the LLM smarter permanently

**Answer: B** — LLMs can use context provided in the prompt even if it wasn't in training data.

---

**Q7.** What happens when a prompt exceeds the LLM's context window?
- A) The LLM processes it normally
- B) The LLM may truncate, lose, or fail to process the excess content
- C) The LLM automatically summarizes it
- D) Nothing changes

**Answer: B** — Each LLM has a token limit; exceeding it causes loss of information.

---

## Module 3: Prompt Patterns I

**Q8.** What does the Question Refinement Pattern do?
- A) Answers questions faster
- B) Asks the LLM to suggest a better version of the user's question
- C) Filters out bad questions
- D) Generates random questions

**Answer: B** — The LLM proposes an improved question, then the user decides whether to use it.

---

**Q9.** The Cognitive Verifier Pattern works by:
- A) Checking facts against a database
- B) Having the LLM break a complex question into sub-questions and combine their answers
- C) Verifying the user's identity
- D) Running the prompt twice for consistency

**Answer: B** — Decomposing complex questions improves accuracy by addressing each component.

---

**Q10.** The Audience Persona Pattern is useful when:
- A) You want the LLM to adopt a role
- B) You want the response tailored for a specific audience (child, expert, etc.)
- C) You're writing for social media
- D) You need the LLM to ask questions

**Answer: B** — "Explain this to a 10-year-old" or "Explain this to a PhD student" changes depth and vocabulary.

---

## Module 4: Few-Shot Examples

**Q11.** What is the difference between zero-shot and few-shot prompting?
- A) Zero-shot uses no examples; few-shot provides 2-5 examples in the prompt
- B) Zero-shot is free; few-shot costs money
- C) Zero-shot is faster; few-shot is slower
- D) There is no difference

**Answer: A** — Few-shot gives the LLM examples of the desired input/output pattern.

---

**Q12.** Chain-of-thought prompting improves LLM performance on:
- A) Creative writing only
- B) Logical reasoning, math, and multi-step problems
- C) Image generation
- D) Translation only

**Answer: B** — Showing step-by-step reasoning in examples teaches the LLM to reason through problems.

---

**Q13.** What is the primary benefit of few-shot examples?
- A) They reduce token usage
- B) They demonstrate the expected format and reasoning pattern to the LLM
- C) They train the model permanently
- D) They bypass rate limits

**Answer: B** — Examples act as in-context learning, shaping outputs without fine-tuning.

---

## Module 5: Prompt Patterns II

**Q14.** The Template Pattern is used to:
- A) Generate templates for websites
- B) Define a fill-in-the-blanks format that the LLM must follow
- C) Create email templates
- D) Build programming templates

**Answer: B** — Placeholders in [CAPS] tell the LLM exactly what structure to produce.

---

**Q15.** The Recipe Pattern asks the LLM to:
- A) Cook food
- B) Provide step-by-step instructions to achieve a goal, filling in missing steps
- C) Follow a recipe from a cookbook
- D) Rank recipes

**Answer: B** — You provide partial steps and the LLM completes the full sequence.

---

**Q16.** The Alternative Approaches Pattern is valuable because:
- A) It's faster
- B) It surfaces multiple solutions so you can pick the best one for your context
- C) It's cheaper
- D) It avoids errors

**Answer: B** — Seeing pros/cons of different approaches leads to better decisions.

---

**Q17.** What is Meta Language Creation in prompt engineering?
- A) Creating a new programming language
- B) Inventing custom shorthand notation that the LLM learns to interpret within the conversation
- C) Translating between languages
- D) Writing metadata

**Answer: B** — You define abbreviations or notation and the LLM uses them in context.

---

## Module 6: Prompt Patterns III

**Q18.** The Ask for Input Pattern reverses the typical interaction by:
- A) Making the LLM refuse to answer
- B) Having the LLM ask the user questions to gather enough info for a better response
- C) Requiring the user to write longer prompts
- D) Automating input collection

**Answer: B** — Instead of guessing, the LLM interviews you to produce exactly what you need.

---

**Q19.** The Fact Check List Pattern improves reliability by:
- A) Connecting to the internet
- B) Having the LLM list all verifiable claims at the end of its response
- C) Running fact-checking software
- D) Only using verified sources

**Answer: B** — Users can then independently verify the flagged statements.

---

**Q20.** The Tail Generation Pattern:
- A) Generates a conclusion
- B) Ends each response with a follow-up question or suggested next step
- C) Creates a summary
- D) Adds a disclaimer

**Answer: B** — Keeps conversations productive by naturally suggesting deeper exploration.

---

**Q21.** The Game Play Pattern can be used to:
- A) Play video games
- B) Turn learning or problem-solving tasks into interactive games with the LLM
- C) Create game mods
- D) Test game software

**Answer: B** — Makes tasks engaging: "Create a trivia game about cybersecurity concepts."

---

**Q22.** The Outline Expansion Pattern works by:
- A) Writing everything at once
- B) First generating a high-level outline, then expanding each section independently
- C) Outlining after writing
- D) Skipping the outline

**Answer: B** — Two-step approach: structure first, detail second. Better for long-form content.

---

**Q23.** Which combination of patterns would be MOST effective for writing a technical document?
- A) Game Play + Persona
- B) Persona + Template + Outline Expansion + Fact Check List
- C) Few-Shot only
- D) Question Refinement only

**Answer: B** — Persona sets expertise, Template defines format, Outline structures content, Fact Check ensures accuracy.

---

## Bonus: Pattern Combination Questions

**Q24.** A user wants to plan a vacation. Which pattern combination would help most?
- A) Ask for Input + Recipe + Alternative Approaches
- B) Persona + Game Play
- C) Template + Meta Language
- D) Fact Check + Tail Generation

**Answer: A** — Ask for Input gathers preferences, Recipe provides the step-by-step plan, Alternative Approaches shows different trip options.

---

**Q25.** You need to debug code but aren't sure what the problem is. Best pattern combination?
- A) Persona (senior developer) + Cognitive Verifier + Question Refinement
- B) Template + Game Play
- C) Few-Shot + Tail Generation
- D) Audience Persona + Recipe

**Answer: A** — Persona provides expertise, Cognitive Verifier decomposes the problem, Question Refinement sharpens the debugging question.
