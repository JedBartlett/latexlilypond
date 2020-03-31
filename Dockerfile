# This file started life as:
# https://github.com/microsoft/vscode-dev-containers/blob/v0.101.1/containers/ubuntu-18.04-git/.devcontainer/Dockerfile
# as the basic Ubuntu+git VSCode remote container.
FROM ubuntu:18.04
LABEL force-rebuild="2020/02/29"
# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Configure apt and install packages
# Many of these were taken from:
# https://raw.githubusercontent.com/microsoft/vscode-dev-containers/master/script-library/common-debian.sh
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
      apt-transport-https \
      apt-utils \
      ca-certificates \
      curl \
      dialog \
      fluid-soundfont-gm \
      iproute2 \
      lame \
      less \
      libc6 \
      libgcc1 \
      libgssapi-krb5-2 \
      libicu[0-9][0-9] \
      liblttng-ust0 \
      libstdc++6 \
      locales \
      lsb-release \
      openssh-client \
      perl \
      procps \
      sudo \
      timidity \
      unzip \
      wget \
      zlib1g \
      2>&1 \
    # Fix Locales
    && echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen \
    && dpkg-reconfigure locales

# Install TexLive
# Taken from https://github.com/overleaf/overleaf/blob/master/Dockerfile-base
# ---------------
# CTAN mirrors occasionally fail, in that case install TexLive against an
# specific server, for example http://ctan.crest.fr
#
# # docker build \
#     --build-arg TEXLIVE_MIRROR=http://ctan.crest.fr/tex-archive/systems/texlive/tlnet
ARG TEXLIVE_MIRROR=http://mirror.ctan.org/systems/texlive/tlnet

ENV PATH "${PATH}:/usr/local/texlive/2019/bin/x86_64-linux"

RUN mkdir /install-tl-unx \
&&  curl -sSL \
      ${TEXLIVE_MIRROR}/install-tl-unx.tar.gz \
    | tar -xzC /install-tl-unx --strip-components=1 \
    \
&&  echo "tlpdbopt_autobackup 0" >> /install-tl-unx/texlive.profile \
&&  echo "tlpdbopt_install_docfiles 0" >> /install-tl-unx/texlive.profile \
&&  echo "tlpdbopt_install_srcfiles 0" >> /install-tl-unx/texlive.profile \
&&  echo "selected_scheme scheme-basic" >> /install-tl-unx/texlive.profile \
    \
&&  /install-tl-unx/install-tl \
      -profile /install-tl-unx/texlive.profile \
      -repository ${TEXLIVE_MIRROR}

# Clean up apt
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install lilypond manually
# Manually wget the binaries for lilypond and install them
RUN wget \
    http://lilypond.org/download/binaries/linux-64/lilypond-2.18.2-1.linux-64.sh; \
    sh ./lilypond*.sh --batch ; \
    rm ./lilypond*.sh

# Fix timidity configuration to use the fluid-soundfont-gm sound fonts
# This allows the .midi file to be interpreted and played, so it can be
# converted to .mp3
RUN sed -e 's|^source|#source|' -e '$a source /etc/timidity/fluidr3_gm.cfg' -i /etc/timidity/timidity.cfg

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog

# Install extensions as a layer.
# Look up what texlive package to install to get specific latex packages
# at https://ctan.org/
# (search for the LaTeX package and add the "contained in TeXLive as __")
RUN tlmgr install --repository ${TEXLIVE_MIRROR} \
    # Build/Tooling integration
      # use to solve the "how many times to build" problem in editor
      latexmk \
      # Support for LuaTeX builds (instead of pdflatex) - need for lyluatex
      luatexbase \
      # Perl script that counts words in the text
      texcount \
    # Foundational Dependencies of other packages
      # driver-independent access to several kinds of colors
      xcolor \
      # input and include macros
      currfile \
      # Define new environments
      environ \
      # Hooks (AtBegin, AtEnd) for files read by \input, \include, and \InputIffileExists
      filehook \
      # Expose spacing for TeX logos to optimize for different fonts
      metalogo \
      # Boxes that shrink to the natural width of the longest line they contain
      #  (Dependency of lyluatex for injecting rendered images)
      minibox \
      # Support landscape enfironment of lscape
      pdflscape \
      # Simplify inclusion of external multi-page pdf documents
      pdfpages \
      # Expandably remove spaces around a token list
      trimspaces \
      # Offers macros for setting keys to declare options for classes and packages.
      xkeyval \
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
      lyluatex \
      needspace \
      titlepic \
      titlesec \
    \
&&  rm -rf /install-tl-unx

# This is needed to get the locales to work out properly.
CMD ["/usr/bin/supervisord", "-n"]