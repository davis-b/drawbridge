#include "SDL.h"

  void setPixel(int x, int y, uint32_t color, SDL_Surface *surface) {
  	uint8_t *target_pixel = (uint8_t *)surface->pixels + y * surface->pitch + x * 4;
  	*(uint32_t *)target_pixel = color;
  }

void changeColors(int width, int height, uint32_t colorA, uint32_t colorB, SDL_Surface *surface) {
	for (int x = 0; x < width; x++) {
		for (int y = 0; y < height; y++) {
			uint8_t *target_pixel = (uint8_t *)surface->pixels + y * surface->pitch + x * 4;
			if (! (y % 20  && x % 20)) {
			  	*(uint32_t *)target_pixel = colorB; 
			}
			*target_pixel += 1; 
		}
	}
}

void inverseColors(int width, int height, uint32_t colorA, uint32_t colorB, SDL_Surface *surface) {
	for (int x = 0; x < width; x++) {
		for (int y = 0; y < height; y++) {
			uint8_t *target_pixel = (uint8_t *)surface->pixels + y * surface->pitch + x * 4;
			if (*target_pixel < 100) {
			   	*(uint32_t *)target_pixel = colorA; 
			}
			else { *(uint32_t *)target_pixel = colorB; }
		}
	}
}
