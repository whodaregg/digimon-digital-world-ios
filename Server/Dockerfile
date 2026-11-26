FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY relay.py .
ENV HOST=0.0.0.0 PORT=8765
EXPOSE 8765
USER nobody
CMD ["python", "relay.py"]
