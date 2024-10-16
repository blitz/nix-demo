from setuptools import setup, find_packages

setup(
    name="hello_world_project",  # Name of the package
    version="0.1.0",  # Version
    packages=find_packages(),  # Automatically finds the packages in the project
    entry_points={
        'console_scripts': [
            'hello-world=hello_world.main:main',  # Exposes a command-line script
        ],
    },
    author="Peter Schmidt",
    author_email="peter.schmidt@example.com",
    description="A simple Hello World Python package",
    python_requires='>=3.6',
)
