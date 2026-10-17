# Inception
*This project has been created as part of the 42 curriculum by aabi-mou.*

# Description

# Docker Usage and Design Choices

## Virtual Machines vs Docker
Both provide virtualization (abstraction layer).
For vms, this layer us called a hypervisor, which manages the allocation of resources between different vms. Each vm runs it own operation system, using "virtual" hardware, borrowed from host computer.
Docker uses a containerization layer and allows to package an application and its dependencies into a container, by pulling an image. A Dockerfile provides the recipe to create an image.
Docker shares the host kernel, while a vm has its own os kernel.
Use cases of vms: diverse os
Use cases of docker: microservices


## Secrets vs Environment Variables


## Docker Network vs Host Network
In a bridge network, each container has its own ip address. A host forwards traffic to a specified port inside the container.
In a host network, each container shares the host's network environment, no need to specify ports (-p flag).

## Docker Volumes vs Bind Mounts


# Instructions


# Resources
