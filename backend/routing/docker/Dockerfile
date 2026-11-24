# Production Valhalla Routing Engine Dockerfile for SurakshaPath
# Base: Ubuntu 22.04 LTS with Valhalla C++17 build
FROM ghcr.io/valhalla/valhalla:latest

LABEL maintainer="SurakshaPath Engineering Team <dev@surakshapath.org>"
LABEL description="Valhalla Routing Microservice for Andhra Pradesh Statewide Evacuation"
LABEL data_license="OpenStreetMap Contributors (ODbL 1.0)"

WORKDIR /custom_files

# Copy Valhalla production configuration
COPY ../config/valhalla.json /custom_files/valhalla.json

# Expose Valhalla HTTP routing port
EXPOSE 8002

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8002/status || exit 1

# Start Valhalla service daemon
CMD ["valhalla_service", "/custom_files/valhalla.json", "2"]
