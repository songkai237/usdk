package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"github.com/songkai/usdk/backend/internal/config"
	"github.com/songkai/usdk/backend/internal/eth"
	"github.com/songkai/usdk/backend/internal/handler"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}

	ethClient, err := eth.NewClient(cfg)
	if err != nil {
		log.Fatal(err)
	}

	h := handler.New(ethClient)

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"http://localhost:5173", "http://127.0.0.1:5173"},
		AllowedMethods:   []string{"GET", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Content-Type"},
		AllowCredentials: false,
	}))

	r.Mount("/", h.Routes())

	addr := fmt.Sprintf(":%s", cfg.Port)
	log.Printf("USDK BFF listening on %s (chain %d)", addr, cfg.Deployment.ChainID)
	log.Fatal(http.ListenAndServe(addr, r))
}
