APP_NAME := shell2telegram
APP_DESCRIPTION := $$(awk 'NR == 11, NR == 13' README.md)
APP_URL := https://github.com/msoap/$(APP_NAME)
APP_MAINTAINER := $$(git show HEAD | awk '$$1 == "Author:" {print $$2 " " $$3 " " $$4}')
GIT_TAG := $$(git tag 2>/dev/null | grep -E '^[0-9]+' | tail -1)

run:
	go run $$(ls *.go | grep -v _test.go) $${TB_ROOT:+-root-users=$$TB_ROOT} \
        -add-exit \
        -log-commands \
        -persistent_users \
        /date:desc="Get current date" date \
        /:plain_text:desc="Numbers via cat -n" 'cat -n' \
        /alarm:vars=SLEEP,MSG 'sleep $$SLEEP; echo Hello $$S2T_USERNAME, $$MSG'

build:
	go build

test:
	go test -race -cover -v ./...

lint:
	golint ./...
	go vet ./...
	errcheck ./...

update-from-github:
	go get -u github.com/msoap/$(APP_NAME)

build-docker-image:
	rocker build

gometalinter:
	gometalinter --vendor --cyclo-over=25 --line-length=150 --dupl-threshold=150 --min-occurrences=3 --enable=misspell --deadline=10m

generate-manpage:
	cat README.md | grep -v "^\[" | perl -pe 's/\<img.+\>//' > $(APP_NAME).md
	docker run --rm -v $$PWD:/app -w /app msoap/ruby-ronn ronn $(APP_NAME).md
	mv ./$(APP_NAME) ./$(APP_NAME).1
	rm ./$(APP_NAME).{md,html}

create-debian-amd64-package:
	GOOS=linux GOARCH=amd64 go build -ldflags="-w" -o $(APP_NAME)
	docker run --rm -v $$PWD:/app -w /app msoap/ruby-fpm \
		fpm -s dir -t deb --force --name $(APP_NAME) -v $(GIT_TAG) \
			--license="$$(head -1 LICENSE)" \
			--url=$(APP_URL) \
			--description="$(APP_DESCRIPTION)" \
			--maintainer="$(APP_MAINTAINER)" \
			--category=network \
			./$(APP_NAME)=/usr/bin/ \
			./$(APP_NAME).1=/usr/share/man/man1/ \
			LICENSE=/usr/share/doc/$(APP_NAME)/copyright \
			README.md=/usr/share/doc/$(APP_NAME)/
	rm $(APP_NAME)
