.PHONY: build up down logs test

build:
	docker compose build

up:
	docker compose up --build

down:
	docker compose down

logs:
	docker compose logs --follow api

test:
	docker compose run --rm --build test
