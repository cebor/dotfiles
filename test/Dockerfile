# Local reproduction of a CI test job.
#
#   docker build -f test/Dockerfile -t dot-test .
#   docker run --rm dot-test

FROM ubuntu:24.04

# shellcheck writes the offending source line back out, and this repo's comments
# are full of em-dashes. In the images' default C locale that is a hard error
# ("commitBuffer: invalid argument"), not a garbled character.
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

COPY test/ci-deps.sh /tmp/ci-deps.sh
RUN bash /tmp/ci-deps.sh && rm /tmp/ci-deps.sh

# The suite must not run as root — see the comment in ci-deps.sh.
COPY --chown=runner:runner . /home/runner/dotfiles
USER runner
WORKDIR /home/runner/dotfiles

CMD ["./dot", "test"]
