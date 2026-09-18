# Link — shortcuts that always load Supabase keys from local .env
# Usage: make run | make build-web | make build-apk

ENV_FILE ?= .env
FLUTTER_DEFINES = --dart-define-from-file=$(ENV_FILE)

.PHONY: run build-web build-apk build-ios test analyze

run:
	flutter run $(FLUTTER_DEFINES)

build-web:
	flutter build web --release --base-href /app/ $(FLUTTER_DEFINES)
	mkdir -p site/public/app
	rsync -a --delete --delete-excluded --exclude 'assets/.env' --exclude '.last_build_id' build/web/ site/public/app/

build-apk:
	flutter build apk --release $(FLUTTER_DEFINES)

build-ios:
	flutter build ipa --release $(FLUTTER_DEFINES)

test:
	flutter test

analyze:
	flutter analyze lib/ test/
