FROM python:3.8-alpine

RUN apk update && apk add curl

# Dir setup
ENV APP_DIR /app
RUN mkdir ${APP_DIR}
WORKDIR ${APP_DIR}

COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install flask && \
    pip install -r requirements.txt

COPY app.py .

ENTRYPOINT ["python", "app.py"]
