# Prompt Engineering for ChatGPT — Complete Study Guide

## Module 1: Course Introduction (2 hrs)

### Key Concepts
- **LLMs (Large Language Models)**: AI systems trained on massive text datasets that generate human-like text responses
- **Prompts**: Natural language instructions/questions given to LLMs
- **Randomness in Output**: LLMs produce varied responses due to temperature/sampling — same prompt can yield different results
- **Expert users** who understand prompt engineering are orders of magnitude more productive

### Video Summaries
1. **Meal Plan Example** — Shows LLM capability: fusing Ethiopian + Uzbekistani cuisine into a keto meal plan. Demonstrates complex, creative multi-constraint tasks.
2. **Course Overview** — Covers what you'll learn: patterns, approaches, building from basic to sophisticated prompts.
3. **Speech Pathologist Example** — Using LLM to act as a domain expert. Early intro to the Persona Pattern.
4. **What are LLMs?** — How they work: trained on internet text, predict next tokens, emerge with reasoning capabilities.
5. **Randomness in Output** — Temperature controls creativity vs determinism. Lower = more predictable. Higher = more creative.

### Assignment: Creating Your First Prompts
- Practice writing basic prompts
- Experiment with different phrasings
- Observe how small changes affect output

---

## Module 2: Introduction to Prompts (4 hrs)

### Key Concepts
- **Prompt**: Any text input to an LLM that shapes its response
- **Prompt Intuition**: Understanding WHY certain prompts work — LLMs complete patterns from training data
- **Everyone Can Program**: Prompts are a form of programming accessible to non-coders
- **Prompt Patterns**: Reusable templates for common tasks
- **Persona Pattern**: Tell the LLM to "act as" a specific role (doctor, lawyer, teacher, etc.)
- **New Information**: You can teach the LLM things it doesn't know by including context in the prompt
- **Prompt Size Limitations**: Context window limits how much text you can include
- **Repeated Use**: Good prompts can be saved and reused like tools
- **Root Prompts**: System-level prompts that set behavior for an entire conversation

### The Persona Pattern
**Format:**
```
Act as [persona]. Provide [outputs] using [persona's expertise].
```
**Examples:**
- "Act as a cybersecurity expert. Review this code for vulnerabilities."
- "Act as a nutritionist. Create a meal plan for someone with diabetes."
- "Act as a senior software engineer. Review this architecture."

### Assignments
1. Understanding Prompt Patterns
2. Using the Persona Pattern effectively

---

## Module 3: Prompt Patterns I (2 hrs)

### Key Concepts
- **Root Prompts & Context Control**: How to set up conversations with persistent instructions
- **Question Refinement Pattern**: Ask the LLM to improve your question before answering it
- **Cognitive Verifier Pattern**: Break complex questions into sub-questions for better answers
- **Audience Persona Pattern**: Tell the LLM who the answer is FOR (explain to a 5-year-old, to a PhD, etc.)

### Question Refinement Pattern
**Format:**
```
Whenever I ask a question, suggest a better version of the question and ask me if I'd like to use it instead.
```
**Why it works:** LLMs often know better ways to frame questions than users do.

### Cognitive Verifier Pattern
**Format:**
```
When I ask a question, generate additional sub-questions that help you give a more accurate answer. Then combine the answers to produce the final response.
```
**Why it works:** Breaking complex problems into parts improves accuracy.

### Assignment: Applying Prompt Patterns I

---

## Module 4: Few-Shot Examples (2 hrs)

### Key Concepts
- **Few-Shot Learning**: Providing examples in the prompt to guide the LLM's output format and style
- **Zero-Shot**: No examples — just instructions
- **One-Shot**: One example
- **Few-Shot**: 2-5 examples showing the pattern
- **Chain-of-Thought**: Show reasoning steps in examples to improve logical tasks
- **Output Format Control**: Use examples to define exact output structure (JSON, tables, lists, etc.)

### Few-Shot Pattern
**Format:**
```
Here are examples of [task]:

Input: [example 1 input]
Output: [example 1 output]

Input: [example 2 input]  
Output: [example 2 output]

Now do this:
Input: [your actual input]
Output:
```

### Chain-of-Thought Example
```
Q: Roger has 5 tennis balls. He buys 2 cans of 3 tennis balls each. How many does he have?
A: Roger started with 5 balls. 2 cans of 3 = 6 balls. 5 + 6 = 11. The answer is 11.

Q: [Your question]
A: Let me work through this step by step...
```

### Assignment: Few-Shot Examples

---

## Module 5: Prompt Patterns II (3 hrs)

### Key Concepts
- **Template Pattern**: Define a fill-in-the-blanks template for structured output
- **Meta Language Creation**: Invent shorthand notation the LLM understands
- **Recipe Pattern**: Get step-by-step instructions for achieving a goal
- **Alternative Approaches Pattern**: Ask LLM to suggest different ways to solve a problem
- **Combining Patterns**: Stack multiple patterns for powerful compound prompts

### Template Pattern
**Format:**
```
I'm going to give you a template for your output. Everything in [CAPS] is a placeholder. Preserve the formatting.

[TITLE]
Author: [AUTHOR]
Summary: [ONE PARAGRAPH SUMMARY]
Key Points:
- [POINT 1]
- [POINT 2]
- [POINT 3]
```

### Recipe Pattern
**Format:**
```
I want to achieve [goal]. I know I need to [partial steps]. Give me the complete sequence of steps, filling in any missing ones.
```

### Alternative Approaches Pattern
**Format:**
```
If there are alternative ways to accomplish [task], list the best approaches, compare their pros/cons, and recommend the best one for [context].
```

### Assignment: Applying Prompt Patterns II

---

## Module 6: Prompt Patterns III (5 hrs)

### Key Concepts
- **Ask for Input Pattern**: Make the LLM ask YOU questions to produce better output
- **Outline Expansion Pattern**: Generate an outline first, then expand each section
- **Menu Actions Pattern**: Create a menu of actions the LLM can perform
- **Fact Check List Pattern**: Ask LLM to list all facts in its response that should be verified
- **Tail Generation Pattern**: End each response with a follow-up question or next step
- **Semantic Filter Pattern**: Filter content based on meaning, not keywords
- **Game Play Pattern**: Turn tasks into interactive games

### Ask for Input Pattern
**Format:**
```
From now on, I want you to ask me questions to help you [task]. Ask me enough questions until you have enough information to [produce the output I need].
```

### Fact Check List Pattern
**Format:**
```
After every response, generate a list of statements in your response that could be fact-checked and list them at the end as "Things to verify: [list]"
```

### Tail Generation Pattern
**Format:**
```
At the end of each response, ask me a question that would help us go deeper into the topic or address a related concern.
```

### Game Play Pattern
**Format:**
```
Create a game about [topic]. The rules are [rules]. Start the game.
```

### Assignment: Applying Prompt Patterns III

---

## Quick Reference: All Prompt Patterns

| Pattern | One-liner | Module |
|---------|-----------|--------|
| Persona | "Act as X" | 2 |
| Question Refinement | "Suggest a better question" | 3 |
| Cognitive Verifier | "Break into sub-questions" | 3 |
| Audience Persona | "Explain for audience X" | 3 |
| Few-Shot Examples | Show input/output pairs | 4 |
| Chain-of-Thought | Show reasoning steps | 4 |
| Template | Fill-in-the-blanks output | 5 |
| Meta Language | Custom shorthand | 5 |
| Recipe | Step-by-step with gaps filled | 5 |
| Alternative Approaches | Compare multiple methods | 5 |
| Ask for Input | LLM asks you questions | 6 |
| Outline Expansion | Outline then expand | 6 |
| Menu Actions | Menu of available actions | 6 |
| Fact Check List | List verifiable claims | 6 |
| Tail Generation | End with follow-up question | 6 |
| Semantic Filter | Filter by meaning | 6 |
| Game Play | Turn task into a game | 6 |
