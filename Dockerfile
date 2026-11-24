FROM python:3.13.14-slim AS base
WORKDIR /opt/program
COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt
ENV PYTHONUNBUFFERED=1 OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1

FROM base AS training
COPY src/train.py .
ENV WORKSHOP_DATA_PATH=/opt/ml/input/data/train/complaints.csv \
    WORKSHOP_MODEL_DIR=/opt/ml/model
ENTRYPOINT ["python", "train.py"]

FROM base AS serving
COPY src/serve.py .
EXPOSE 8080
ENTRYPOINT ["python", "serve.py"]
CMD ["serve"]
