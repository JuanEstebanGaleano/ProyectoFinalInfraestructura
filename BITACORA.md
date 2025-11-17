Introducción

El presente proyecto tiene como propósito la implementación de una
infraestructura computacional basada en tecnologías de virtualización y
contenedorización, con el fin de integrar servicios distribuidos de
manera eficiente y segura.

A través de la creación de arreglos RAID 1, la configuración de
volúmenes lógicos LVM y la ejecución de contenedores Docker y Podman, se
busca garantizar la persistencia, tolerancia a fallos y portabilidad de
los servicios.

Los servicios desplegados ---Apache, MySQL y Nginx--- representan una
arquitectura típica de servidores web y de base de datos en entornos
empresariales.

El desarrollo de este proyecto permite afianzar conocimientos en
almacenamiento redundante, administración de volúmenes, virtualización,
gestión de contenedores y automatización de despliegues, pilares
fundamentales de la infraestructura moderna en la nube.

**Marco teórico**

RAID (Redundant Array of Independent Disks) combina múltiples discos
duros en un solo sistema lógico para mejorar el rendimiento y la
tolerancia a fallos. En este proyecto se utilizó RAID 1 (espejo), que
duplica los datos en dos discos para garantizar la integridad ante
fallos.

LVM (Logical Volume Manager) permite administrar el almacenamiento de
forma flexible mediante volúmenes físicos (PV), grupos de volúmenes (VG)
y volúmenes lógicos (LV), posibilitando ampliaciones y respaldos sin
interrupciones.

La virtualización crea máquinas virtuales independientes, mientras que
la contenedorización, a través de Docker y Podman, aísla aplicaciones en
entornos ligeros. Docker utiliza un demonio central, mientras que Podman
opera sin daemon, ofreciendo mayor seguridad y compatibilidad con
imágenes Docker.

Los servicios implementados fueron: Apache (servidor web), MySQL (gestor
de bases de datos), Nginx (proxy inverso y balanceador) y phpMyAdmin
(interfaz web para MySQL). La persistencia se logró montando volúmenes
LVM sobre los contenedores, asegurando la conservación de datos incluso
tras reinicios.

**Definiciones clave**

-   Contenedor: Entorno aislado que ejecuta una aplicación junto con sus
    dependencias.

-   Imagen: Plantilla inmutable que contiene el sistema base y archivos
    necesarios para crear un contenedor.

-   Volumen: Directorio persistente montado dentro del contenedor para
    conservar datos.

-   Dockerfile: Archivo de instrucciones para construir una imagen
    personalizada.

-   Pod: Conjunto de contenedores que comparten red y almacenamiento,
    concepto adoptado por Podman y Kubernetes.

Actividades

Estructura del proyecto:

![A screenshot of a computer AI-generated content may be
incorrect.](media/image1.png){width="5.653559711286089in"
height="4.436458880139982in"}

1.  Verificar los discos disponibles sudo fdisk -l

![](media/image2.png){width="6.1375in" height="3.4444444444444446in"}

**Observación:** Se listan los discos conectados al sistema y se
identifican los discos para empezar con la fase 1

  ---------------------------------------------------------------------------------
  **Propósito**   **Disco 1**              **Disco 2**              **Resultado**
  --------------- ------------------------ ------------------------ ---------------
  Apache          /dev/sdb →               /dev/sdc →               /dev/md0
                  **APACHE.vdi**           **PRUEBA1.vdi**          

  MySQL           /dev/sdd → **MySQL.vdi** /dev/sde →               /dev/md1
                                           **PRUEBA2.vdi**          

  Nginx           /dev/sdf →               /dev/sdg →               /dev/md2
                  **Nginx1vdi.vdi**        **PRUEBA3.vdi**          
  ---------------------------------------------------------------------------------

![A screenshot of a computer program AI-generated content may be
incorrect.](media/image3.png){width="6.0216808836395455in"
height="2.021117672790901in"}

-   **FASE 1 --- Configuración de RAID 1:** El objetivo será crear 3
    arreglos RAID 1 (espejo) con los discos virtuales disponibles.
    Además, cada RAID servirá luego como base para un volumen LVM que
    usará un contenedor diferente.

![](media/image4.png){width="6.1375in" height="4.670138888888889in"}

**Observación:** Los códigos que se emplearon fueron los siguientes para
la creación de los respectivos RAIDS:

**\# RAID 1 para Apache**

sudo mdadm \--create \--verbose /dev/md0 \--level=1 \--raid-devices=2
/dev/sdb /dev/sdc

**\# RAID 1 para MySQL**

sudo mdadm \--create \--verbose /dev/md1 \--level=1 \--raid-devices=2
/dev/sdd /dev/sde

**\# RAID 1 para Nginx**

sudo mdadm \--create \--verbose /dev/md2 \--level=1 \--raid-devices=2
/dev/sdf /dev/sdg

-   **Explicación del funcionamiento de los comandos:**

-   \--create → crea un nuevo arreglo RAID.

-   \--level=1 → indica RAID 1 (espejo).

-   \--raid-devices=2 → usa dos discos por arreglo.

-   Cada arreglo genera un nuevo dispositivo virtual /dev/mdX.

2.  **Verificación del estado de los RAID y guardar su configuración:**

![A computer screen shot of white text AI-generated content may be
incorrect.](media/image5.png){width="6.1375in"
height="2.339583333333333in"}

> **Observación:** Se verifica el estado actual de los arreglos RAID.
> Esta acción permite registrar la configuración de los RAIDs en el
> sistema, garantizando su montaje automático al reiniciar el equipo.
> Los comandos ejecutados fueron los siguientes:

-   cat /proc/mdstat: Verificación del estado de los arreglos RAID
    activos.

-   sudo mdadm \--detail \--scan \| sudo tee -a /etc/mdadm/mdadm.conf:
    Registro de la información de los RAIDs en el archivo de
    configuración del sistema.

-   sudo update-initramfs -u: Actualización del sistema para guardar y
    aplicar la configuración de los RAIDs.

![A computer screen shot of a program AI-generated content may be
incorrect.](media/image6.png){width="6.095833333333333in"
height="2.0104166666666665in"}

-   **Verificar cada RAID en detalle**

> ![](media/image7.png){width="6.411472003499562in"
> height="3.669752843394576in"}
>
> ![A computer screen shot of a computer AI-generated content may be
> incorrect.](media/image8.png){width="6.235444006999125in"
> height="3.2795002187226596in"} ![A computer screen shot of a computer
> AI-generated content may be
> incorrect.](media/image9.png){width="6.177175196850394in"
> height="3.2292147856517937in"}
>
> Posteriormente, se consultan los detalles de cada arreglo RAID
> mediante los siguientes comandos:

-   sudo mdadm \--detail /dev/md0

-   sudo mdadm \--detail /dev/md1

-   sudo mdadm \--detail /dev/md2

> Al ejecutar estos comandos, se muestra información detallada sobre
> cada dispositivo, incluyendo:

-   Estado: active

-   Nivel: raid1

-   Discos activos y sincronizados

-   Tamaño total disponible

> Esta verificación permite confirmar que los arreglos RAID se
> encuentran operativos y correctamente sincronizados, asegurando la
> integridad de los datos y la disponibilidad del sistema.

-   **FASE 2 --- Configuración de LVM sobre RAID**

> **Objetivo:** Crear la capa de administración de volúmenes lógicos
> sobre los arreglos RAID existentes, siguiendo tres metas:

1.  Crear un Physical Volume (PV) sobre cada dispositivo RAID
    administrado con mdadm.

![A computer screen shot of white text AI-generated content may be
incorrect.](media/image10.png){width="6.1375in"
height="1.7673611111111112in"}

-   Se preparan los arreglos RAID para su gestión con LVM, convirtiendo
    cada uno en un volumen físico reconocible por el sistema. Para ello,
    se inicializa LVM sobre cada dispositivo RAID con los siguientes
    comandos:

```{=html}
<!-- -->
```
-   sudo pvcreate /dev/md0

-   sudo pvcreate /dev/md1

-   sudo pvcreate /dev/md2

```{=html}
<!-- -->
```
-   Con esta acción, cada RAID queda listo para integrarse en grupos de
    volúmenes y permitir la creación de volúmenes lógicos destinados a
    los datos de los servicios.

2.  Definir un Volume Group (VG) y crear grupos de almacenamiento
    independientes para cada servicio. Cada servicio debe contar con su
    propio espacio de almacenamiento, de manera que no interfiera con
    los demás. Esta separación permite organizar, expandir y mantener el
    almacenamiento de manera clara y ordenada, asegurando que cada
    servicio se gestione por separado y de forma eficiente.

![A computer screen shot of white text AI-generated content may be
incorrect.](media/image11.png){width="5.938336614173228in"
height="1.312684820647419in"}

-   sudo vgcreate vg_apache /dev/md0

-   sudo vgcreate vg_mysql /dev/md1

-   sudo vgcreate vg_nginx /dev/md2

3.  Provisionar un Logical Volume (LV) por servicio para alojar los
    datos de cada contenedor.

![](media/image12.png){width="5.948745625546807in"
height="1.4689545056867892in"}

-   sudo lvcreate -l 100%FREE -n lv_apache vg_apache

-   sudo lvcreate -l 100%FREE -n lv_mysql vg_mysql

-   sudo lvcreate -l 100%FREE -n lv_nginx vg_nginx

> La opción -l 100%FREE crea el volumen usando todo el espacio libre
> disponible del grupo de almacenamiento. Cada volumen lógico generará
> un dispositivo accesible en el sistema:

-   /dev/vg_apache/lv_apache

-   /dev/vg_mysql/lv_mysql

-   /dev/vg_nginx/lv_nginx

4.  Formatear los volúmenes con EXT4 para dejarlos listos para su uso
    por los servicios. Se aplica el sistema de archivos ext4 a cada
    volumen lógico con los siguientes comandos:

-   sudo mkfs.ext4 /dev/vg_apache/lv_apache

-   sudo mkfs.ext4 /dev/vg_mysql/lv_mysql

-   sudo mkfs.ext4 /dev/vg_nginx/lv_nginx

Con este paso, cada volumen queda preparado para ser montado y utilizado
por los contenedores correspondientes.

![](media/image13.png){width="6.1877701224846895in"
height="5.291897419072616in"}

5.  Crear puntos de montaje

![A computer screen shot of white text AI-generated content may be
incorrect.](media/image14.png){width="6.105018591426072in"
height="0.9793033683289589in"}

Crear los directorios donde se montarán los volúmenes. Se definen los
puntos de montaje para cada servicio con los siguientes comandos:

-   sudo mkdir -p /mnt/apache_vol

-   sudo mkdir -p /mnt/mysql_vol

-   sudo mkdir -p /mnt/nginx_vol

Con esto, cada servicio dispone de una carpeta específica donde se
conectará su volumen correspondiente.

6.  Montar los volúmenes

> ![A black background with white text AI-generated content may be
> incorrect.](media/image15.png){width="6.1375in"
> height="0.7319444444444444in"}
>
> Montar los volúmenes para que queden disponibles en sus carpetas de
> trabajo. Se conectan cada volumen lógico con su punto de montaje
> correspondiente mediante:

-   sudo mount /dev/vg_apache/lv_apache /mnt/apache_vol

-   sudo mount /dev/vg_mysql/lv_mysql /mnt/mysql_vol

-   sudo mount /dev/vg_nginx/lv_nginx /mnt/nginx_vo

> Con este paso, los servicios pueden leer y escribir en sus ubicaciones
> asignadas de manera inmediata.

7.  Verificar que todo quedó correctamente montado y visible en el
    sistema. Utiliza los siguientes comandos de comprobación:

-   lsblk para visualizar los dispositivos, sus volúmenes lógicos y los
    puntos de montaje; confirma que /dev/vg_apache/lv_apache aparece en
    /mnt/apache_vol, /dev/vg_mysql/lv_mysql en /mnt/mysql_vol y
    /dev/vg_nginx/lv_nginx en /mnt/nginx_vol.

-   mount \| grep /mnt para listar únicamente los montajes bajo /mnt y
    verificar que cada volumen está activo en su carpeta.

-   df -h para revisar capacidad total, usada y disponible de cada punto
    de montaje y confirmar que se reconocen como ext4.

> ![A screenshot of a computer program AI-generated content may be
> incorrect.](media/image16.png){width="6.4375in"
> height="5.697916666666667in"}

  ---------------------------------------------------------------------------
  **Servicio**   **RAID**    **VG**        **LV**       **Punto de montaje**
  -------------- ----------- ------------- ------------ ---------------------
  Apache         /dev/md0    vg_apache     lv_apache    /mnt/apache_vol

  MySQL          /dev/md1    vg_mysql      lv_mysql     /mnt/mysql_vol

  Nginx          /dev/md2    vg_nginx      lv_nginx     /mnt/nginx_vol
  ---------------------------------------------------------------------------

-   **FASE 3 --- Creación de los Contenedores con Docker**

**Objetivo:** Crear 3 contenedores, cada uno con su servicio

  -----------------------------------------------------------------------
  **Servicio**   **Imagen**              **Volumen persistente**
  -------------- ----------------------- --------------------------------
  Apache         apache_custom           /mnt/apache_vol

  MySQL          mysql_custom            /mnt/mysql_vol

  Nginx          nginx_custom            /mnt/nginx_vol
  -----------------------------------------------------------------------

Cada uno usará una imagen personalizada (con su propio Dockerfile).

1.  **Verifica que Docker está funcionando**

![](media/image17.png){width="6.635416666666667in"
height="2.6666666666666665in"}

Verificación del servicio de Docker. Se comprueba el estado del servicio
para asegurar su disponibilidad operativa en el sistema. En caso de no
estar activo, se procede a su activación inmediata y a su habilitación
para el arranque automático en reinicios posteriores.

-   **Comprobar estado:**

sudo systemctl status docker

-   **Iniciar y habilitar si no está activo:**

sudo systemctl start docker

sudo systemctl enable docker

Con estas acciones, Docker queda en ejecución y configurado para
iniciarse automáticamente, garantizando su disponibilidad para la
gestión de contenedores.

2.  **Crea una carpeta para los Dockerfiles**

![](media/image18.png){width="6.261293744531933in"
height="0.5625787401574803in"}

3.  **Crear el Dockerfile para Apache**

Preparar el espacio de trabajo para construir la imagen del servicio
Apache. Se crea una carpeta dedicada y se accede a ella para organizar
los archivos de construcción:

-   mkdir -p \~/docker_builds/apache

-   cd \~/docker_builds/apache

![A blue screen with white text AI-generated content may be
incorrect.](media/image19.png){width="6.084181977252843in"
height="0.7917771216097987in"}

Con esto se garantiza una estructura ordenada por servicio, facilitando
la gestión de Dockerfiles, recursos y versiones.

![A screenshot of a computer AI-generated content may be
incorrect.](media/image20.png){width="6.1375in"
height="3.4479166666666665in"}

-   Imagen base: se utiliza ubuntu:22.04 como punto de partida porque
    proporciona un sistema limpio, estable y ampliamente soportado, lo
    que facilita reproducibilidad y mantenimiento.

-   Instalación del servicio: se instalan los paquetes de Apache
    necesarios dentro de la imagen para disponer del servidor web y sus
    utilidades básicas, garantizando que la aplicación pueda atender
    solicitudes HTTP.

-   Exposición del puerto: se expone el puerto 80, que es el estándar
    para tráfico web HTTP, permitiendo que el contenedor reciba
    conexiones desde el host o desde otros servicios de la red.

-   Proceso en primer plano: se configura el arranque de Apache en
    primer plano para que el proceso principal del contenedor permanezca
    activo; en Docker, si el proceso PID 1 termina, el contenedor se
    detiene, por lo que ejecutar Apache en foreground asegura su
    disponibilidad continua.

![A computer screen shot AI-generated content may be
incorrect.](media/image21.png){width="6.708333333333333in"
height="2.625in"}

Construcción de la imagen del servicio Apache. Se posiciona el contexto
de compilación en la carpeta del proyecto y se ejecuta la construcción
etiquetando la imagen para su fácil identificación local.

-   Ubicar el contexto:

    -   cd \~/docker_builds/apache

-   Construir y etiquetar:

    -   sudo docker build -t apache_custom.

Con esta acción se genera una imagen local llamada apache_custom, a
partir del Dockerfile en el directorio actual, lista para ser usada en
contenedores.

![](media/image22.png){width="6.29254593175853in"
height="3.771360454943132in"}

Verifica que el archivo quedó bien y la imagen con el comando **cat
Dockerfile** y **sudo docker images**

4.  **Crear el Dockerfile para MySQL**

![](media/image23.png){width="6.2821259842519686in"
height="0.41672462817147854in"}

5.  **Crear el Dockerfile para MySQL**

Preparar el espacio de trabajo para construir la imagen del servicio
MySQL. Se crea una carpeta dedicada y se accede a ella para organizar
los archivos de construcción:

-   mkdir -p \~/docker_builds/mysql

-   cd \~/docker_builds/mysql

![](media/image24.png){width="6.292548118985127in"
height="0.5625787401574803in"}

![A black and purple rectangle with white lines AI-generated content may
be incorrect.](media/image25.png){width="6.447916666666667in"
height="1.3506944444444444in"}

Crear el archivo Dockerfile para el servicio de base de datos MySQL. Se
genera el archivo y se define una imagen basada en MySQL 8 con variables
de entorno mínimas y el puerto estándar expuesto.

-   **Abrir/crear el archivo:**

sudo nano Dockerfile

-   **Contenido del Dockerfile:**

FROM mysql:8.0

ENV MYSQL_ROOT_PASSWORD=root

ENV MYSQL_DATABASE=clientes

EXPOSE 3306

Este Dockerfile usa la imagen oficial mysql:8.0, establece la contraseña
del usuario root y crea la base de datos inicial indicada mediante
variables de entorno, además de exponer el puerto 3306 para conexiones
al servidor MySQL.

![](media/image26.png){width="6.323800306211724in"
height="1.5835542432195975in"}

Verifica que el archivo quedó bien y la imagen con el comando **cat
Dockerfile** y **sudo docker images**

![](media/image27.png){width="6.572916666666667in"
height="3.048611111111111in"}

Verificación del Dockerfile y construcción de la imagen personalizada.
Se valida que el archivo Dockerfile contenga exactamente las
instrucciones previstas y, posteriormente, se construye una imagen
personalizada basada en MySQL 8.0. La advertencia de seguridad observada
se debe al uso de variables de entorno con datos sensibles dentro de la
imagen, por lo que se documenta su causa y la forma recomendada de
mitigación.

-   **Verificar contenido del Dockerfile:** cat Dockerfile

-   **Debe coincidir con:**

FROM mysql:8.0

ENV MYSQL_ROOT_PASSWORD=root

ENV MYSQL_DATABASE=clientes

EXPOSE 3306

-   **Construir la imagen:** sudo docker build -t mysql_custom

-   **Qué significa la advertencia:** Docker desaconseja definir
    secretos dentro de una imagen con ENV, porque quedan almacenados en
    las capas y pueden leerse si alguien accede a la imagen o a su
    historial. El mensaje "Do not use ARG or ENV for sensitive data"
    indica ese riesgo y sugiere usar mecanismos alternativos de paso de
    credenciales en tiempo de ejecución.

-   **Opción A (recomendada en escenarios con orquestación):** usar
    Docker Secrets para inyectar la contraseña en tiempo de ejecución,
    evitando guardarla en la imagen. Esto permite referenciar un archivo
    secreto dentro del contenedor en lugar de un valor en texto plano.

-   **Opción B (escenario simple sin Swarm):** No poner la contraseña en
    el Dockerfile. Definirla al ejecutar el contenedor mediante una
    variable de entorno externa o un archivo montado, manteniendo el
    secreto fuera del control de versiones.

-   **Opción C (endurecimiento adicional de MySQL):** Se utiliza el
    MYSQL_RANDOM_ROOT_PASSWORD para que la imagen genere una contraseña
    aleatoria en la inicialización y luego rotarla de forma segura.

Con estas modificaciones, el Dockerfile resulta adecuado para propósitos
académicos y, al mismo tiempo, se deja constancia de una práctica segura
para el manejo de credenciales en entornos de producción, evitando su
inclusión directa en la imagen.

![](media/image28.png){width="6.3342180664916885in"
height="3.4588167104111984in"}

Verifica que el archivo quedó bien y la imagen con el comando **cat
Dockerfile** y **sudo docker images**

6.  **Crear el Dockerfile para Nginx**

![A screenshot of a computer screen AI-generated content may be
incorrect.](media/image29.png){width="6.131837270341207in"
height="0.5889916885389326in"}

7.  **Crear el archivo index.html dentro de la carpeta:**

Preparar el espacio de trabajo para construir la imagen del servicio
Nginx. Se crea una carpeta dedicada y se accede a ella para organizar
los archivos de construcción:

-   mkdir -p \~/docker_builds/Nginx

-   cd \~/docker_builds/Nginx

![Blue text on a black background AI-generated content may be
incorrect.](media/image30.png){width="6.138357392825896in"
height="0.7917771216097987in"}

![A black and white rectangular object AI-generated content may be
incorrect.](media/image31.png){width="6.1375in"
height="0.8819444444444444in"}

-   **Creación del Dockerfile para Nginx y página de prueba:** Se define
    una imagen basada en Nginx que publica el puerto 80 y despliega una
    página HTML sencilla para verificar el correcto funcionamiento del
    servicio.

-   **Contenido del Dockerfile:**

FROM nginx:latest

COPY ./index.html /usr/share/nginx/html/index.html

EXPOSE 80

8.  **Crear el archivo index.html en la carpeta del proyecto:** echo
    \"\<h1\>Servidor Nginx funcionando correctamente\</h1\>\" \>
    \~/docker_builds/nginx/index.html

Con esta configuración, al construir y ejecutar la imagen, Nginx servirá
la página index.html en el puerto 80, permitiendo comprobar visualmente
que el contenedor responde como se espera.

![A screenshot of a computer program AI-generated content may be
incorrect.](media/image32.png){width="6.635416666666667in"
height="1.8284722222222223in"}

9.  **Ejecutar los contenedores con volúmenes RAID/LVM**

![](media/image33.png){width="6.5954866579177605in"
height="1.3128455818022746in"}

**Ejecución de los contenedores con volúmenes y puertos asignados:** Se
inician los servicios Apache, MySQL y Nginx en modo desatendido,
mapeando puertos y montando los volúmenes persistentes para sus datos y
contenidos.

-   **Apache (puerto 8080 → 80, contenido en /mnt/apache_vol):** sudo
    docker run -d \--name cont_apache -p 8080:80 -v
    /mnt/apache_vol:/var/www/html apache_custom

-   **MySQL (datos en /mnt/mysql_vol; nota: la contraseña se define aquí
    solo con fines académicos):** sudo docker run -d \--name cont_mysql
    -e MYSQL_ROOT_PASSWORD=root -v /mnt/mysql_vol:/var/lib/mysql
    mysql_custom

-   **Nginx (puerto 8081 → 80, contenido en /mnt/nginx_vol):** sudo
    docker run -d \--name cont_nginx -p 8081:80 -v
    /mnt/nginx_vol:/usr/share/nginx/html nginx_custom

Con estos comandos, cada servicio queda aislado en su contenedor, con
datos persistentes en los volúmenes LVM montados y accesibles desde los
puertos publicados del host.

10. **Pruebas de funcionamiento**

-   **Verificación de contenedores en ejecución:** Comando utilizado
    sudo Docker ps![](media/image34.png){width="6.1375in"
    height="0.6597222222222222in"}

-   **Servidor utilizando Apache:** Dirección que vamos a emplear para
    realizar la prueba del funcionamiento localhost:8080

![A computer screen shot of a white screen AI-generated content may be
incorrect.](media/image35.png){width="6.086181102362205in"
height="2.658571741032371in"}

-   **Servidor utilizando Nginx:** Dirección que vamos a emplear para
    realizar la prueba del funcionamiento localhost:8081![A computer
    screen with a white screen AI-generated content may be
    incorrect.](media/image36.png){width="6.076053149606299in"
    height="3.0221128608923884in"}

-   **Servidor de MySQL:**

1.  **Accede a la base de datos:** Empleando el comando **s**udo docker
    exec -it cont_mysql mysql -u root -p# contraseña: root![A screenshot
    of a computer screen AI-generated content may be
    incorrect.](media/image37.png){width="6.1375in"
    height="2.6972222222222224in"}![A screenshot of a computer program
    AI-generated content may be
    incorrect.](media/image38.png){width="6.1954910323709536in"
    height="4.326280621172353in"}

-   **Base de datos de MySQL utilizando phpMyAdmin:**

2.  **Crea y ejecuta el contenedor phpMyAdmin:** Comandos utilizados
    para la creación del contenedor

sudo docker run -d \\ \--name phpmyadmin \\

> -e PMA_HOST=cont_mysql \\

e PMA_USER=root \\

-e PMA_PASSWORD=root \\

-p 8082:80 \\

> \--link cont_mysql:db \\
>
> phpmyadmin/phpmyadmin

![](media/image39.png){width="5.756492782152231in"
height="4.982007874015748in"}

-   **Verificar que estén funcionando los contenedores:**

![](media/image40.png){width="6.395833333333333in"
height="1.3333333333333333in"}

-   **Interfaz de phpMyAdmin:** Se accede desde el navegador utilizando
    la url <http://localhost:8082> y validamos la base de datos de
    cliente que creamos anteriormente utilizando nuestra terminal

![A computer screen shot of a computer AI-generated content may be
incorrect.](media/image41.png){width="6.1375in"
height="3.4506944444444443in"}

![A computer screen shot of a computer screen AI-generated content may
be incorrect.](media/image42.png){width="6.1375in"
height="3.4506944444444443in"}

Para visualizar la base de datos MySQL en entorno web utilicé
phpMyAdmin, ejecutado como contenedor Docker vinculado al contenedor
MySQL, lo que demuestra la integración entre servicios y la
virtualización de aplicaciones con volúmenes persistentes.

3.  **Prueba de persistencia Apache:**

-   Crea o modifica un archivo dentro del volumen, por ejemplo:

![](media/image43.png){width="6.1375in" height="0.4222222222222222in"}

-   **Reinicia el contenedor:** sudo docker restart cont_apache

```{=html}
<!-- -->
```
-   Primera captura antes de reiniciar el contenedor:

![A computer screen shot of a computer AI-generated content may be
incorrect.](media/image44.png){width="6.1375in"
height="3.4506944444444443in"}

-   **Segunda captura después de reiniciarlo**

![](media/image45.png){width="6.989583333333333in" height="1.46875in"}

-   **Observación técnica -- Mensaje AH00558 en Apache durante la
    ejecución del contenedor Apache, el registro de Docker mostró el
    siguiente mensaje:**

AH00558: apache2: Could not reliably determine the server\'s fully
qualified domain name, using 172.17.0.2. Set the \'ServerName\'
directive globally to suppress this message.

-   **Explicación:** Este mensaje no representa un error. Indica que
    Apache no tiene configurado un nombre de dominio (ServerName), por
    lo cual usa la dirección IP interna del contenedor (172.17.0.2) como
    nombre por defecto.

-   **Solución aplicada (opcional):** Se puede eliminar agregando la
    línea: ServerName localhost en el archivo /etc/apache2/apache2.conf.
    Sin embargo, no afecta el funcionamiento del servicio, por lo que se
    mantuvo como observación en la bitácora.

![A computer screen with a white screen AI-generated content may be
incorrect.](media/image46.png){width="6.1375in"
height="3.4506944444444443in"}

-   **Prueba de persistencia utilizando MySQL**

1.  Ingresamos al contenedor: **sudo docker exec -it cont_mysql mysql -u
    root -p**

2.  **Nos conectamos a la base de datos:** Utilizando la contraseña de
    root y el comando use clientes;

3.  **Crea una nueva tabla:**

CREATE TABLE persistencia2 (

id INT PRIMARY KEY,

descripcion VARCHAR(100)

);

![](media/image47.png){width="5.922860892388451in"
height="3.4367213473315834in"}

4.  **Creamos un dato de prueba:** INSERT INTO persistencia2 VALUES (1,
    \'Segunda prueba de persistencia con RAID y LVM\');
    ![](media/image48.png){width="6.1375in"
    height="0.7145833333333333in"}

5.  **Se verifica que se insertó correctamente:** SELECT \* FROM
    persistencia2;

![A computer screen with white text AI-generated content may be
incorrect.](media/image49.png){width="5.834148075240595in"
height="1.6252274715660542in"}

6.  **Prueba de persistencia:** Utilizamos los siguientes comandos
    después de salirnos de la base de datos utilizando exit

sudo docker restart cont_mysql

sudo docker exec -it cont_mysql mysql -u root -p

USE clientes;

SELECT \* FROM persistencia2;

![](media/image50.png){width="6.105018591426072in"
height="3.2191994750656168in"}

-   **Se verifica en phpMyAdmin para ver si esta la persistencia al
    momento de hacer los pasos anteriores**

![A screenshot of a computer AI-generated content may be
incorrect.](media/image51.png){width="6.1375in"
height="3.4506944444444443in"}

4.  **Prueba de persistencia en Nginx: Objetivo:** Comprobar que los
    archivos del servidor web Nginx se mantienen tras reiniciar el
    contenedor.

```{=html}
<!-- -->
```
1.  **Entrar al volumen: Vamos a modificar el archivo directamente en el
    volumen:** echo \"\<h1\>Prueba de persistencia Nginx\</h1\>\" \|
    sudo tee /mnt/nginx_vol/index.html

![](media/image52.png){width="6.1375in" height="0.4013888888888889in"}

2.  **Verifica desde el navegador o terminal:**

> **Captura con persistencia**
>
> ![A screenshot of a computer AI-generated content may be
> incorrect.](media/image53.png){width="5.931765091863517in"
> height="3.1761176727909013in"}

3.  **Reinicia el contenedor:** Comando que utilizaremos sudo docker
    restart cont_nginx

> ![](media/image54.png){width="5.864583333333333in"
> height="0.3104166666666667in"}
>
> ![A screen shot of a computer AI-generated content may be
> incorrect.](media/image55.png){width="5.884543963254593in"
> height="2.4381310148731408in"}

1.  **Resultado Final Fase 3**

  ---------------------------------------------------------------------------------
  **Servicio**   **Contenedor**   **Puerto**      **Volumen (LVM)**    **Estado**
  -------------- ---------------- --------------- -------------------- ------------
  Apache         cont_apache      8080            /mnt/apache_vol      ✅

  MySQL          cont_mysql       interno 3306    /mnt/mysql_vol       ✅

  Nginx          cont_nginx       8081            /mnt/nginx_vol       ✅
  ---------------------------------------------------------------------------------

2.  **Fase 5 --- Implementación con Podman**

**Objetivo:** Ejecutar los mismos contenedores (Apache, MySQL y Nginx)
usando Podman, demostrando compatibilidad con Docker y persistencia en
los volúmenes RAID/LVM.

1.  **Instalación de Podman**

![A screenshot of a computer program AI-generated content may be
incorrect.](media/image56.png){width="6.1375in"
height="4.147222222222222in"}

Comandos utilizados para realizar la instalación de podman en nuestra
máquina virtual:

sudo apt update

sudo apt install -y podman

2.  **Comprobación de compatibilidad con Docker**

![A screenshot of a computer screen AI-generated content may be
incorrect.](media/image57.png){width="3.3129625984251967in"
height="0.718850612423447in"}

Podman puede ejecutar los mismos comandos que Docker: alias
docker=podman, además, esto permite usar exactamente los mismos docker
run, docker ps, docker build, etc., pero con Podman debajo.

3.  **Crear los contenedores en Podman**

-   **Apache**

-   **Nginx**

-   **Mysql**

![](media/image58.png){width="6.1375in" height="2.0430555555555556in"}

**Observación:** Saco error por qué ya se había creado el contenedor de
apache, por ende, dice que el nombre ya está en uso

4.  **Verificación de funcionamiento:** sudo podman ps

![](media/image59.png){width="6.1375in" height="0.5673611111111111in"}

5. **Integración de Netdata (Monitoreo del Sistema)**

Netdata es una herramienta de monitoreo en tiempo real que permite visualizar métricas detalladas del sistema y de los contenedores. Su incorporación al proyecto tiene como finalidad supervisar el rendimiento de los servicios Apache, MySQL, Nginx y phpMyAdmin, así como el estado de los volúmenes RAID/LVM y el uso de recursos del sistema.

Netdata proporciona gráficos en tiempo real de CPU, memoria, procesos, disco, red, tráfico entre contenedores y rendimiento de servicios web y bases de datos. Esto añade un componente de observabilidad fundamental para la administración moderna de infraestructura.

Ejecución del contenedor Netdata con Podman

Para implementar Netdata no fue necesario crear Dockerfile ni Containerfile, ya que existe una imagen oficial completamente funcional. Se ejecutó con permisos adecuados para leer métricas del sistema host:

sudo podman run -d --name netdata \
  -p 19999:19999 \
  -v netdataconfig:/etc/netdata:Z \
  -v netdatalib:/var/lib/netdata:Z \
  -v netdatacache:/var/cache/netdata:Z \
  --cap-add SYS_PTRACE \
  --security-opt label=disable \
  docker.io/netdata/netdata:latest

**Explicación técnica del comando**

-p 19999:19999: expone el panel web para monitoreo.

Volúmenes persistentes: garantizan que Netdata mantenga configuraciones e historiales.

--cap-add SYS_PTRACE: permite inspeccionar procesos del host.

--security-opt label=disable: necesario para que Podman permita acceso a métricas del sistema.

Imagen oficial: netdata/netdata:latest.

Acceso al dashboard

Luego de iniciar el contenedor, se accede a la interfaz gráfica mediante:

http://localhost:19999


Desde allí se puede visualizar:

Estado del sistema (CPU, RAM, carga, I/O).

Actividad de contenedores Apache, MySQL, Nginx y phpMyAdmin.

Lecturas/escrituras en RAID 1 (md0, md1, md2).

Uso de volúmenes lógicos LVM.

Tráfico de red entre contenedores internos de Podman.

Alertas en tiempo real sobre fallos o sobrecargas.

Importancia de Netdata dentro del proyecto

La inclusión de Netdata permitió:

Observar en tiempo real el rendimiento del sistema y de cada servicio.

Validar la correcta operación de los volúmenes RAID/LVM bajo carga.

Identificar cuellos de botella potenciales.

Confirmar la estabilidad de los contenedores bajo Docker y Podman.

Incorporar un componente de monitoreo profesional típico en entornos DevOps.

**Conclusiones**

El desarrollo del proyecto permitió implementar una infraestructura
modular, segura y persistente aplicando principios de redundancia y
virtualización. RAID y LVM garantizaron la integridad de los datos;
Docker y Podman demostraron la portabilidad y eficiencia de los
servicios. Las pruebas de persistencia confirmaron la conservación de la
información tras reinicios, validando la robustez del diseño.

Este proyecto demuestra cómo las tecnologías de contenedores y las
estrategias de almacenamiento redundante constituyen la base de la
infraestructura moderna en entornos DevOps y empresariales.

**Referencias bibliográficas**

-   Docker Inc. (2024). Docker Documentation. Recuperado de
    https://docs.docker.com

-   Red Hat, Inc. (2024). Podman User Guide. Recuperado de
    https://podman.io/getting-started/

-   The Linux Foundation. (2024). Linux Logical Volume Manager (LVM).

-   Apache Software Foundation. (2024). Apache HTTP Server
    Documentation.

-   Oracle Corporation. (2024). MySQL Reference Manual.

-   NGINX, Inc. (2024). NGINX Documentation.

-   Stallings, W. (2022). Operating Systems: Internals and Design
    Principles. Pearson Education.
