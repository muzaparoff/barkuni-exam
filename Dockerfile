FROM python:3.11-slim AS base
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
EXPOSE 5000

CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]