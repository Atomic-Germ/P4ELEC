# Makefile for AmberG350

# Variables
SQUASHFS_IMAGE := AmberG350.squashfs
BUILD_DIR := build
SYSTEM_ROOT := $(BUILD_DIR)/system
DOCKER_IMAGE := amberg350-build
DOCKER_TAG := latest
PREBUILT_IMAGE_URL := https://github.com/AmberELEC/AmberELEC/releases/download/20230203/AmberELEC-RG351MP.aarch64-20230203.img.gz
PREBUILT_IMAGE_GZ := $(BUILD_DIR)/prebuilt.img.gz
PREBUILT_IMAGE := $(BUILD_DIR)/prebuilt.img
FINAL_IMAGE := AmberG350.img
MOUNT_POINT := $(BUILD_DIR)/mnt

.PHONY: all build clean docker-build shell package-image

all: build

# Build the squashfs image
build:
	@echo "Building squashfs image..."
	@mkdir -p $(SYSTEM_ROOT)
	@echo "Note: Building from AmberELEC overlay only"
	@echo "For full image, use 'make package-image' which merges with base system"
	@rsync -av --delete AmberELEC/ $(SYSTEM_ROOT)/
	@mksquashfs $(SYSTEM_ROOT) $(SQUASHFS_IMAGE) -noappend -comp xz

# Clean up build artifacts
clean:
	@echo "Cleaning up..."
	@rm -rf $(BUILD_DIR)
	@rm -f $(SQUASHFS_IMAGE)
	@rm -f $(FINAL_IMAGE)

# Package the squashfs into the pre-built image
package-image:
	@echo "Packaging squashfs into pre-built image..."
	@mkdir -p $(BUILD_DIR) $(MOUNT_POINT) $(SYSTEM_ROOT)
	@echo "Downloading pre-built image..."
	@wget -q -O $(PREBUILT_IMAGE_GZ) $(PREBUILT_IMAGE_URL) || (echo "Failed to download image"; exit 1)
	@echo "Decompressing image..."
	@gunzip -c $(PREBUILT_IMAGE_GZ) > $(PREBUILT_IMAGE)
	@echo "Setting up loop device..."
	@sudo losetup -fP $(PREBUILT_IMAGE)
	@sleep 1
	@echo "Mounting partition to extract original SYSTEM..."
	@sudo mount $$(sudo losetup -j $(PREBUILT_IMAGE) | cut -d: -f1)p1 $(MOUNT_POINT)
	@echo "Checking original SYSTEM squashfs info..."
	@sudo unsquashfs -s $(MOUNT_POINT)/SYSTEM || true
	@echo "Extracting original SYSTEM squashfs..."
	@sudo unsquashfs -f -d $(SYSTEM_ROOT) $(MOUNT_POINT)/SYSTEM
	@echo "Backing up critical files before overlay..."
	@sudo cp -a $(SYSTEM_ROOT)/usr/lib/systemd $(BUILD_DIR)/systemd.backup || true
	@sudo cp -a $(SYSTEM_ROOT)/usr/bin/autostart.sh $(BUILD_DIR)/autostart.backup || true
	@echo "Unmounting to prepare for overlay..."
	@sudo umount $(MOUNT_POINT)
	@sudo losetup -d $$(sudo losetup -j $(PREBUILT_IMAGE) | cut -d: -f1)
	@echo "Overlaying AmberELEC changes onto extracted system..."
	@sudo rsync -rlptgoDv --no-owner --no-group --exclude='usr/lib/libreelec/fs-resize' AmberELEC/ $(SYSTEM_ROOT)/
	@echo "Verifying critical boot files still exist..."
	@sudo test -f $(SYSTEM_ROOT)/usr/bin/autostart.sh || echo "WARNING: autostart.sh missing!"
	@sudo test -d $(SYSTEM_ROOT)/usr/lib/systemd || echo "WARNING: systemd directory missing!"
	@echo "Creating new SYSTEM squashfs with merged content..."
	@sudo mksquashfs $(SYSTEM_ROOT) $(SQUASHFS_IMAGE) -noappend -comp gzip -b 1M -no-xattrs -noappend
	@sudo chown $(USER):$(USER) $(SQUASHFS_IMAGE)
	@echo "Re-mounting image to replace SYSTEM..."
	@sudo losetup -fP $(PREBUILT_IMAGE)
	@sleep 1
	@sudo mount $$(sudo losetup -j $(PREBUILT_IMAGE) | cut -d: -f1)p1 $(MOUNT_POINT)
	@echo "Replacing SYSTEM with merged version..."
	@sudo cp $(SQUASHFS_IMAGE) $(MOUNT_POINT)/SYSTEM
	@echo "Syncing and unmounting..."
	@sudo sync
	@sudo umount $(MOUNT_POINT)
	@echo "Detaching loop device..."
	@sudo losetup -d $$(sudo losetup -j $(PREBUILT_IMAGE) | cut -d: -f1)
	@echo "Creating final image..."
	@cp $(PREBUILT_IMAGE) $(FINAL_IMAGE)
	@echo "Package complete: $(FINAL_IMAGE)"

# Build the Docker image
docker-image:
	@echo "Building Docker image..."
	@docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

# Run the build inside a Docker container
docker-build: docker-image
	@echo "Running build inside Docker container..."
	@docker run --rm -v $(CURDIR):/build $(DOCKER_IMAGE):$(DOCKER_TAG) make build

# Get a shell inside the build container
shell: docker-image
	@echo "Starting shell in Docker container..."
	@docker run --rm -it -v $(CURDIR):/build $(DOCKER_IMAGE):$(DOCKER_TAG) /bin/bash