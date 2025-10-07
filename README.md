# Top level convenience build environment, tested on Fedora 40/41

## Run the following for the first time

make firmware-setup firmware-rebuild firmware-copy setup-dev-link install-all build-all build-gui

## Run the following for rebuild firmware
make firmware-rebuild firmware-copy

## Run the following for rebuilding dev
make build-all build-gui

## Run the deploy command to upload new version to gitio
make deploy


  
