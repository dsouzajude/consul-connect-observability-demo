
UNAME_S ?= $(shell uname -s)
STAT_COMMAND = "$(shell if [ "$(UNAME_S)" = 'Linux' ]; then echo "stat -c '%Y'"; else echo "stat -f'%m'"; fi)"


# -----------------------
# Terraform Metadata Vars
# -----------------------
# Extract the path to the base directory of the github repo
DIR_NAME = demo
DEMO_DIR = $(firstword $(subst $(DIR_NAME), ,$(PWD)))$(DIR_NAME)

TFVAR_FILE_PATH = $(DEMO_DIR)/terraform/demo.tfvars.json
PLANFILE ?= "tf-demo$(subst .tfvars.json,,$(TFVAR_FILENAME)).plan"

all:
	$(MAKE) plan


# -----------
# Validations
# -----------

validate:
# Validate if TFVAR_FILE_PATH exists
ifeq ("$(wildcard $(TFVAR_FILE_PATH))","")
	$(error VARFILE=$(TFVAR_FILE_PATH) does not exist)
endif


# --------------
# Terraform Mgmt
# --------------

# Initialize state backend
init: validate
	@rm -f .terraform/terraform.tfstate
	@terraform init --force-copy --backend-config=$(TFVAR_FILE_PATH)

# Runs a plan
plan: init
	@rm -f "$(PLANFILE)"
	@terraform plan -input=false \
					-refresh=true $(PLAN_ARGS) \
					-out=$(PLANFILE) \
					-var-file=$(TFVAR_FILE_PATH)

# Applies the plan
apply:
	@if [ ! -r "$(PLANFILE)" ]; then echo "You need to plan first!" ; exit 14; fi
	@if [ $$(($(shell date +'%s')-$(shell "$(STAT_COMMAND)" "$(PLANFILE)"))) -gt 180 ]; then echo "Plan file is older than 3 minutes; Aborting!" ; exit 15; fi
	@terraform apply -input=true -refresh=true $(PLANFILE)

# Runs a plan to destroy
plan-destroy: init
	@terraform plan -destroy \
					-input=false \
					-refresh=true $(PLAN_ARGS) \
					-out=$(PLANFILE) \
					-var-file=$(TFVAR_FILE_PATH)

clean:
	rm -f *.plan
	rm -rf .terraform
