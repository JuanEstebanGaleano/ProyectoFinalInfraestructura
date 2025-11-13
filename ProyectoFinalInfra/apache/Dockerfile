# Imagen base
FROM ubuntu:22.04

# Instalar Apache
RUN apt update && apt install -y apache2 && apt clean

# Configurar servicio
EXPOSE 80
CMD ["apachectl", "-D", "FOREGROUND"]
