FROM python:3.10-slim-buster

WORKDIR /usr/local/bin

RUN pip install pandas numpy

COPY validate.py .
RUN chmod +x validate.py