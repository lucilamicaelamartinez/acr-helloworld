FROM python:3.10-slim-bullseye
ENV FLASK_DEBUG=production
ENV PROD_DATABASE_URI=""
ENV PYTHONUNBUFFERED=1
ENV PATH=$PATH:/home/flaskapp/.local/bin

#creamos un usuario flaskapp
RUN useradd --create-home --home-dir /home/flaskapp flaskapp
#establecemos el directorio de trabajo
WORKDIR /home/flaskapp
USER flaskapp
RUN mkdir app
#copia la carpeta del proyecto a la imagen
#COPY ./main ./main

COPY ./app.py .

ADD requirements.txt ./requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

#puerto por el que escucha la imagen
EXPOSE 5000
CMD [ "python", "./app.py" ]%
