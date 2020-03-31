# LaTeX and LilyPond Dev Container

This container is meant to be used with the
[VSCode Remote-Containers](https://code.visualstudio.com/docs/remote/containers)
extension and also as part of any CI/CD pipeline for LaTeX/LilPond projects.

## Available Commands

Although it is, of course, slightly more complicated,
the image produced by this project is meant to support the following
commands and packages.

- *latex*
  - **tlmgr** The package manager for installing the packages you choose to use
  - **lualatex** the lua-based compiler used to create PDFs (instead of pdflatex)
  - **latexmk** A command to wrap the compilation of lualatex to ensure that the right
              number of compile steps are performed.  Basically a 'make' system for
              latex documents.
  - *lyluatex* Allow embedding of musical notation inside of the PDF using lilypond
  - *pgf* Provide the tikz package for creating drawings in latex
- **lilypond** compile ABC notation in .ly files into .pdf and .midi files
- **timidity** convert .midi files into playable sound
- **lame** mp3 encoder, convert playable sound into .mp3

## Expected Use

### Commands to Run With This Container

Run these commands from the root of this repository to get a feeling for how
to use this docker container as a build system.

The --mount portion of each of the below commands is to mount the local
filesystem into the container.

1. Use the container to build a latex document with embedded lilypond music.
   Notes on what this command does:
   - **--mount ...** - Mount in the test folder to have some working material
   - **jedibart/latexlilypond** - The name of the image -
     *Strongly suggest adding `:<version>` of the released version* if using as a build
     container that you want to stay stable.
   - **/bin/sh -c** Use the shell to execute the remaining commands passed in as a string.
     - **cd /testfiles &&** Change directory into the mounted location so relative references
       to externally included files work properly. `&&` is just shell for "And", which means
       also execute the remaining commands if the change directory command works.
     - **latexmk** - Use the latex mk system to ensure the document is compiled the correct
       number of times to work out all the page numbering and references properly.
     - **-shell-escape** - Argument to the compiler that allows it to call back out to the
       shell and execute other programs (in this case, the lilypond compiler.)
     - **-pdflatex=lualatex** - Use the lualatex compiler instead of the default pdflatex.
       This is a requirement of the lyluatex package to work.
     - **-pdf** - Make the output a PDF (not strictly needed)
     - ***.tex** - Compile all of the `.tex` files found in the working directory.
  
   ```sh
   docker run \
   --mount type=bind,src=$(pwd)/testfiles/,dst=/testfiles jedibart/latexlilypond \
   /bin/sh -c "cd /testfiles && latexmk -shell-escape -pdflatex=lualatex -pdf *.tex"
   ```

2. Use the container to build a lilypond file (that also produces a .midi file)
   See notes above for most of the explanation, but instead of calling latexmk in this case,
   we will call the lilypond compiler and pass in the `TestScore.ly` file.

   ```sh
   docker run \
   --mount type=bind,src=$(pwd)/testfiles/,dst=/testfiles jedibart/latexlilypond \
   /bin/sh -c "cd /testfiles && lilypond TestScore.ly"
   ```

3. Use the container to pass in the .midi produced output from the last step into a
   .mp3 file that can be played to hear what you wrote.
   The command passed into the docker container this time runs `timidity` to produce an audio
   output stream, and then pipes that into the `lame` .mp3 encoder.

   ```sh
   docker run \
   --mount type=bind,src=$(pwd)/testfiles/,dst=/testfiles jedibart/latexlilypond \
   /bin/sh -c "cd /testfiles && timidity TestScore.midi -Ow -o - | lame - -b 64 TestScore.mp3"
   ```

### VSCode .devcontainer

In a VScode project repository, create the following files in the root of the
project directory

```plain
.devcontainer/
├── devcontainer.json
└── Dockerfile
```

The devcontainer.json content should look something like this:

```yaml
// For format details, see https://aka.ms/vscode-remote/devcontainer.json
# This file started life as:
# https://github.com/microsoft/vscode-dev-containers/blob/v0.101.1/containers/ubuntu-18.04-git/.devcontainer/Dockerfile
# as the basic Ubuntu+git VSCode remote container.
FROM latexlilypond

# This Dockerfile adds a non-root user with sudo access. Use the "remoteUser"
# property in devcontainer.json to use it. On Linux, the container user's GID/UIDs
# will be updated to match your local UID/GID (when using the dockerFile property).
# See https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Set to false to skip installing zsh and Oh My ZSH!
ARG INSTALL_ZSH="false"

# Location and expected SHA for common setup script - SHA generated on release
ARG COMMON_SCRIPT_SOURCE="https://raw.githubusercontent.com/microsoft/vscode-dev-containers/master/script-library/common-debian.sh"
ARG COMMON_SCRIPT_SHA="dev-mode"

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Verify git, common tools / libs installed, add/modify non-root user, optionally install zsh
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
      git \
    && wget -q -O /tmp/common-setup.sh $COMMON_SCRIPT_SOURCE \
    && if [ "$COMMON_SCRIPT_SHA" != "dev-mode" ]; then echo "$COMMON_SCRIPT_SHA /tmp/common-setup.sh" | sha256sum -c - ; fi \
    && /bin/bash /tmp/common-setup.sh "$INSTALL_ZSH" "$USERNAME" "$USER_UID" "$USER_GID" \
    && rm /tmp/common-setup.sh

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog


# This is needed to get the locales to work out properly.
CMD ["/usr/bin/supervisord". "-n"]
```

Dockerfile should start off simply referencing this container
(Note, suggest using official tags and not floating to latest):

```dockerfile
FROM jedibart/latexlilypond:latest

# This Dockerfile adds a non-root user with sudo access. Use the "remoteUser"
# property in devcontainer.json to use it. On Linux, the container user's GID/UIDs
# will be updated to match your local UID/GID (when using the dockerFile property).
# See https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Set to false to skip installing zsh and Oh My ZSH!
ARG INSTALL_ZSH="true"

# Location and expected SHA for common setup script - SHA generated on release
ARG COMMON_SCRIPT_SOURCE="https://raw.githubusercontent.com/microsoft/vscode-dev-containers/master/script-library/common-debian.sh"
ARG COMMON_SCRIPT_SHA="dev-mode"

# CTAN mirrors occasionally fail, in that case install TexLive against an
# specific server, for example http://ctan.crest.fr
#
# # docker build \
#     --build-arg TEXLIVE_MIRROR=http://ctan.crest.fr/tex-archive/systems/texlive/tlnet
ARG TEXLIVE_MIRROR=http://mirror.ctan.org/systems/texlive/tlnet

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Configure apt and install packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends apt-utils dialog wget ca-certificates 2>&1 \
    #
    # Verify git, common tools / libs installed, add/modify non-root user, optionally install zsh
    && wget -q -O /tmp/common-setup.sh $COMMON_SCRIPT_SOURCE \
    && if [ "$COMMON_SCRIPT_SHA" != "dev-mode" ]; then echo "$COMMON_SCRIPT_SHA /tmp/common-setup.sh" | sha256sum -c - ; fi \
    && /bin/bash /tmp/common-setup.sh "$INSTALL_ZSH" "$USERNAME" "$USER_UID" "$USER_GID" \
    && rm /tmp/common-setup.sh \
    #
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog

# Install extensions that you use as \usepackage in your documents.
# Look up what texlive package to install to get specific latex packages
# at https://ctan.org/
# (search for the LaTeX package and add the "contained in TeXLive as __")
RUN tlmgr install --repository ${TEXLIVE_MIRROR} \
    # Packages that aren't self-named ( see https://ctan.org/)
      # graphicsx contained in TeXLive as graphics
      graphics \
      # tikz - in TeXLive as pgf
      pgf \
      # multicol, verbatim in TeXLive as tools
      tools \
    # Self-named packages
      enumitem \
      fancyhdr \
      geometry \
      needspace \
    \
&&  rm -rf /install-tl-unx

```

The same dockerfile can be used as part of a CICD pipeline,
simply build the image on the host machine,
and then pass in the compile operations one wishes to accomplish.

## Background

The [lilypond-book](https://lilypond.org/doc/v2.19/Documentation/usage/latex)
script was used to allow embeding of lilypond files into LaTeX using a LaTeX syntax.

This was nice, but it had the problem of needing to have a pre-latex compile step,
and resulted in the use of some make-file or other build system/script to put things
together, and didn't integrate seamlessly with an editor like VSCode or Atom.

Enter the [lyluatex](https://ctan.org/pkg/lyluatex?lang=en) package, which combines
the two by allowing the lualatex compile to do the call-out itself.
This works great, and allows a singular compile/development environment through
VSCode (although I still make use of frescobaldi editor outside of the strict dev env
to create the .ly lilypond music).

However, there's some setup/config/tying together to install the right dependencies,
allow luaLaTeX to call out to an external process,
and have dictionaries for spellright spell-checkers installed properly;
hence, this repository as the basis for a
[VSCode Remote-Containers](https://code.visualstudio.com/docs/remote/containers)
project and utilization of GitHub CI/CD Actions based pipelines.

## Other Similar Projects

This is a bit of a niche kind of development environment,
so there aren't too many similar efforts. The ones I did discover were either not
actively maintained or not setup in a way I was comfortable leveraging heavily.

### Discovered on Dockerhub

- [tsunaminoai/lilypond](https://hub.docker.com/r/tsunaminoai/lilypond)
  This project was not updated for 2 years at the time I started this repository,
  and I couldn't find the source-code.
- [jperon/sharelatex-music](https://hub.docker.com/r/jperon/sharelatex-music)
