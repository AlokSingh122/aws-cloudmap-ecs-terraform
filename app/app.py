import os
import platform
import socket

from flask import Flask, jsonify, render_template

app = Flask(__name__)

APP_NAME = os.getenv("APP_NAME", "CloudMap ECS demo")
AWS_REGION = os.getenv("AWS_REGION", "unknown")

PROJECT_SKILLS = [
    "Amazon ECR",
    "Amazon ECS",
    "EC2 Spot capacity",
    "API Gateway HTTP API",
    "AWS Cloud Map",
    "Terraform",
]

PROJECT_ARCHITECTURE = [
    {
        "title": "Amazon ECR",
        "detail": "Stores the Docker image built for this application.",
    },
    {
        "title": "Amazon ECS",
        "detail": "Runs the container on EC2 Spot capacity in a private subnet.",
    },
    {
        "title": "Cloud Map + API Gateway",
        "detail": "Discovers the ECS service privately and provides the HTTP API entry point.",
    },
]


def project_summary():
    return {
        "name": APP_NAME,
        "status": "ok",
        "infrastructure_as_code": "Terraform",
        "skills": PROJECT_SKILLS,
        "architecture": PROJECT_ARCHITECTURE,
        "aws_architecture": [
            "Terraform defines the VPC, security groups, IAM roles, ECR, ECS, and Cloud Map resources.",
            "Amazon ECR stores the application image.",
            "Amazon ECS capacity-provider managed scaling runs tasks on EC2 Spot capacity.",
            "API Gateway HTTP API routes requests to the ECS service through Cloud Map.",
        ],
    }


@app.get("/")
def home():
    return render_template("index.html", app_name=APP_NAME, app_status="online")


@app.get("/api/status")
def status():
    return jsonify(project_summary())


@app.get("/info")
def info():
    return jsonify(
        **project_summary(),
        hostname=socket.gethostname(),
        container={
            "runtime": "Docker on Amazon ECS",
            "python_version": platform.python_version(),
            "ecs_metadata_available": bool(os.getenv("ECS_CONTAINER_METADATA_URI_V4")),
        },
        aws_region=AWS_REGION,
    )


@app.get("/health")
def health():
    return jsonify(name=APP_NAME, status="ok"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)