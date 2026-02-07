import numpy as np
from PIL import Image

from settings import THRESHOLD



class MapParser:
    def __init__(self, image_path):
        self.grid = []
        self.spawn_pos = (0, 0)
        self.rows = 0
        self.cols = 0
        self.wall_rectangles = []
        self._load(image_path)

    def _load(self, image_path):
        img = Image.open(image_path).convert('L')
        pixels = np.array(img)
        self.rows, self.cols = pixels.shape

        self.grid = [
            [1 if pixels[row, col] < THRESHOLD else 0 for col in range(self.cols)]
            for row in range(self.rows)
        ]

        self.spawn_pos = self._find_safe_spawn()
        self.wall_rectangles = self._merge_walls()

    def _find_safe_spawn(self):
        cx, cy = self.cols // 2, self.rows // 2

        if self.grid[cy][cx] == 0:
            return (cx, cy)

        max_radius = max(self.cols, self.rows) // 2
        for radius in range(1, max_radius, 5):
            for angle in range(0, 360, 15):
                rad = angle * 3.14159 / 180
                x = int(cx + radius * np.cos(rad))
                y = int(cy + radius * np.sin(rad))
                if 0 <= x < self.cols and 0 <= y < self.rows and self.grid[y][x] == 0:
                    return (x, y)

        for row in range(self.rows):
            for col in range(self.cols):
                if self.grid[row][col] == 0:
                    return (col, row)

        return (cx, cy)

    def _merge_walls(self):
        visited = [[False] * self.cols for _ in range(self.rows)]
        rectangles = []

        for row in range(self.rows):
            for col in range(self.cols):
                if self.grid[row][col] != 1 or visited[row][col]:
                    continue

                width = 0
                for c in range(col, self.cols):
                    if self.grid[row][c] == 1 and not visited[row][c]:
                        width += 1
                    else:
                        break

                height = 0
                for r in range(row, self.rows):
                    if all(self.grid[r][c] == 1 and not visited[r][c]
                           for c in range(col, col + width) if c < self.cols):
                        height += 1
                    else:
                        break

                for r in range(row, row + height):
                    for c in range(col, col + width):
                        visited[r][c] = True

                rectangles.append((col, row, width, height))

        return rectangles