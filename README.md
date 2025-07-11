# ROSA (Red Hat OpenShift Service on AWS) Management Environment

This environment provides tools and scripts for managing Red Hat OpenShift Service on AWS clusters.

## Prerequisites

- macOS
- Homebrew
- AWS CLI
- ROSA CLI
- OpenShift CLI (oc)
- kubectl

## Getting Started

1. Run the setup script: `./setup-rosa-environment.sh`
2. Configure AWS credentials: `aws configure`
3. Login to ROSA: `rosa login`
4. Create your first cluster: `./scripts/create-rosa-cluster.sh`

## Directory Structure

```
rosa/
├── scripts/           # Management scripts
├── configs/          # Configuration templates
├── templates/        # Kubernetes/OpenShift templates
├── logs/            # Operation logs
├── docs/            # Documentation
└── README.md        # This file
```

## Quick Commands

- Check environment: `./scripts/check-environment.sh`
- Create cluster: `./scripts/create-rosa-cluster.sh`
- Delete cluster: `./scripts/delete-rosa-cluster.sh`
- Get cluster status: `./scripts/cluster-status.sh`
- Scale cluster: `./scripts/scale-cluster.sh`

## Documentation

See the `docs/` directory for detailed guides and best practices:

- `setup-guide.md` - Detailed setup instructions
- `troubleshooting.md` - Common issues and solutions
- `best-practices.md` - ROSA best practices
- `vm-ssh-password-auth.md` - VM SSH password authentication configuration
