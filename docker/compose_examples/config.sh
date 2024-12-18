DBGPT_TONGYI_API_KEY=""
DBGPT_OB_HOST=""
DBGPT_OB_PORT="3306"
DBGPT_OB_USER=""
DBGPT_OB_PASSWORD=""
DBGPT_OB_DATABASE="obdbgpt"

# GraphRAG config
GRAPH_STORE_TYPE=TuGraph
TUGRAPH_HOST=127.0.0.1
TUGRAPH_PORT=7687
TUGRAPH_USERNAME=admin
TUGRAPH_PASSWORD=73@TuGraph
GRAPH_COMMUNITY_SUMMARY_ENABLED=True  # enable the graph community summary
TRIPLET_GRAPH_ENABLED=True  # enable the graph search for the triplets
DOCUMENT_GRAPH_ENABLED=True  # enable the graph search for documents and chunks
KNOWLEDGE_GRAPH_CHUNK_SEARCH_TOP_SIZE=5  # the number of the searched triplets in a retrieval
KNOWLEDGE_GRAPH_EXTRACTION_BATCH_SIZE=20  # the batch size of triplet extraction from the text