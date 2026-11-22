FROM partybox-game-builder:draft
COPY --chown=65532:65532 . /game
WORKDIR /game
RUN godot4 --headless --path /game --editor --import
EXPOSE 9082
ENTRYPOINT ["godot4", "--headless", "--path", "/game", "--", "--server"]
CMD []
