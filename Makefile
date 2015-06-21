all:
	docker build -t raumzeitlabor/backup .

run:
	docker run --name=backup --volumes-from=backup-data --rm=true -i -t raumzeitlabor/backup
