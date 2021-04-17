CONTAINER = nginx

ENVIRONMENT = common

.PHONY: build
.PHONY: clean
.PHONY: init
.PHONY: log
.PHONY: run
.PHONY: shell
.PHONY: status


all: clean init build run


build:
	@. envs/$(ENVIRONMENT); \
	docker-compose build $(CONTAINER)


clean:
	@. envs/$(ENVIRONMENT); \
	docker-compose down --remove-orphans; \
	docker-compose rm -fsv $(CONTAINER)


init:
	@. envs/$(ENVIRONMENT); \
	./init.sh; \
	mkdir -p $${HOME}/.aws; \
	[ -f $${HOME}/.aws/config ] || echo "[default]\nregion = $${AWS_REGION}" > $${HOME}/.aws/config; \
	[ -f $${HOME}/.aws/credentials ] || echo "[default]\naws_access_key_id = $${AWS_ACCESS_KEY_ID}\naws_secret_access_key = $${AWS_SECRET_ACCESS_KEY}" > $${HOME}/.aws/credentials; \
	chmod 0600 $${HOME}/.aws/*


log:
	@. envs/$(ENVIRONMENT); \
	docker-compose logs $(CONTAINER)


run: build
	@. envs/$(ENVIRONMENT); \
	docker-compose up -d $(CONTAINER)


shell:
	@. envs/$(ENVIRONMENT); \
	docker-compose exec $(CONTAINER) bash


status:
	@. envs/$(ENVIRONMENT); \
	docker-compose ps --all


prereqs:
	command -v docker >>/dev/null
	docker info >>/dev/null
	command -v docker-compose >>/dev/null
	command -v dig >>/dev/null
	command -v aws >>/dev/null
	aws ec2 describe-instances


ec2: init ec2_bootstrap ec2_provision


ec2_bootstrap:
	@. envs/$(ENVIRONMENT); \
	ansible-playbook -vvv bootstrap.yml


ec2_provision:
	@. envs/$(ENVIRONMENT); \
	ansible-playbook -vvv provision.yml
