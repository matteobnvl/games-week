from engine.game import Game

game = Game('assets/map2.png')


def update():
    game.update()


def input(key):
    game.input(key)


game.run()