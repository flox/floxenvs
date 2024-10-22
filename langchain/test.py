
# import the langchain libraries
from langchain_core.prompts import ChatPromptTemplate
from langchain_ollama.llms import OllamaLLM

# Establish a chat template
template = """Question: {question}

Answer: Let's think step by step."""

prompt = ChatPromptTemplate.from_template(template)

# Load the model
model = OllamaLLM(model="llama3")

# Create the chain
chain = prompt | model

# Gather the response
message = chain.invoke({"question": "What is LangChain?"})
print(message)


