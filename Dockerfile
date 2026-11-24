FROM python:3.13.14-slim
WORKDIR /opt/program
COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt
COPY src/serve.py .
ENV PYTHONUNBUFFERED=1 OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
EXPOSE 8080
ENTRYPOINT ["python", "serve.py"]
CMD ["serve"]
