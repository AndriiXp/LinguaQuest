# Требуется macOS с Xcode 15+ для generate/open/build/test.
# Цель check работает на любой системе с Python 3.

PROJECT = LinguaQuest.xcodeproj
SCHEME = LinguaQuest
DESTINATION = platform=iOS Simulator,name=iPhone 15

.PHONY: generate open build test check clean

generate:
	xcodegen generate

open: generate
	open $(PROJECT)

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' build

test: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' test

# Проверки, не требующие Xcode: схема контента и референсные алгоритмы.
check:
	python3 Tools/validate_content.py
	python3 Tools/reference_algorithms.py

clean:
	rm -rf $(PROJECT) .build DerivedData
