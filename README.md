## To fetch and start a collector 
```curl -sfL https://raw.githubusercontent.com/Incerto-Technologies/release/refs/heads/main/collector/install.sh | sh -s -- --service-url "http://4.213.114.81:8080" --type "worker" --database "clickhouse" --username "default" --endpoint "localhost:9000"```
