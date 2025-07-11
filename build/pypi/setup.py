from setuptools import setup

setup(
    name="giv",
    version="{{VERSION}}",
    description="Git history AI assistant CLI tool",
    author="itlackey",
    author_email="noreply@github.com",
    scripts=["src/giv"],
    data_files=[
        ("src", ["{{SH_FILES}}"]),
        ("templates", ["templates/{{TEMPLATE_FILES}}"]),
        ("docs", ["docs/{{DOCS_FILES}}"]),
    ],
)
