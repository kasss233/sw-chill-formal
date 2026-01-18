
from typing import Annotated, TypedDict
from langgraph.graph.message import add_messages

# 定义状态：这里我们只记录对话消息列表
class State(TypedDict):
    messages: Annotated[list, add_messages]

from langgraph.graph import StateGraph, START, END
from langchain_openai import ChatOpenAI

# 1. 初始化模型
llm = ChatOpenAI(model="gpt-4o")

# 2. 定义一个节点函数
def chatbot(state: State):
    return {"messages": [llm.invoke(state["messages"])]}

# 3. 构建图
workflow = StateGraph(State)

# 添加节点
workflow.add_node("chatbot", chatbot)

# 设置逻辑连线
workflow.add_edge(START, "chatbot") # 从开始进入机器人
workflow.add_edge("chatbot", END)      # 机器人回答完就结束

# 4. 编译并运行
app = workflow.compile()
app.invoke({"messages": [("user", "你好，LangGraph 是什么？")]})