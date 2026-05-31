package handler

import (
	"encoding/json"
	"math/big"
	"net/http"

	"github.com/ethereum/go-ethereum/common"
	"github.com/go-chi/chi/v5"

	"github.com/songkai/usdk/backend/internal/eth"
)

type Handler struct {
	eth *eth.Client
}

func New(ethClient *eth.Client) *Handler {
	return &Handler{eth: ethClient}
}

func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Get("/api/config", h.GetConfig)
	r.Get("/api/prices", h.GetPrices)
	r.Get("/api/position/{address}", h.GetPosition)
	r.Get("/api/position/{address}/health", h.GetHealth)
	r.Get("/api/liquidation/preview", h.LiquidationPreview)
	return r
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func parseAddress(w http.ResponseWriter, s string) (common.Address, bool) {
	if !common.IsHexAddress(s) {
		writeError(w, http.StatusBadRequest, "invalid address")
		return common.Address{}, false
	}
	return common.HexToAddress(s), true
}

func (h *Handler) GetConfig(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, h.eth.GetConfigResponse())
}

func (h *Handler) GetPrices(w http.ResponseWriter, r *http.Request) {
	prices, err := h.eth.GetPrices(r.Context())
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, prices)
}

func (h *Handler) GetPosition(w http.ResponseWriter, r *http.Request) {
	addr, ok := parseAddress(w, chi.URLParam(r, "address"))
	if !ok {
		return
	}
	pos, err := h.eth.GetPosition(r.Context(), addr)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, pos)
}

func (h *Handler) GetHealth(w http.ResponseWriter, r *http.Request) {
	addr, ok := parseAddress(w, chi.URLParam(r, "address"))
	if !ok {
		return
	}
	health, err := h.eth.GetHealth(r.Context(), addr)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, health)
}

func (h *Handler) LiquidationPreview(w http.ResponseWriter, r *http.Request) {
	accountStr := r.URL.Query().Get("account")
	tokenStr := r.URL.Query().Get("token")
	debtStr := r.URL.Query().Get("debtToCover")

	account, ok := parseAddress(w, accountStr)
	if !ok {
		return
	}
	if !common.IsHexAddress(tokenStr) {
		writeError(w, http.StatusBadRequest, "invalid token address")
		return
	}
	token := common.HexToAddress(tokenStr)

	debtToCover, ok := new(big.Int).SetString(debtStr, 10)
	if !ok || debtToCover.Sign() <= 0 {
		writeError(w, http.StatusBadRequest, "invalid debtToCover")
		return
	}

	maxCover, err := h.eth.GetMaxDebtToCover(r.Context(), account)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, err.Error())
		return
	}

	amounts, err := h.eth.GetLiquidationAmounts(r.Context(), account, token, debtToCover)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"maxDebtToCover":    maxCover.String(),
		"finalDebtToCover":  amounts.FinalDebtToCover.String(),
		"collateralAmount":  amounts.CollateralAmount.String(),
		"totalUsdWithBonus": amounts.TotalUsdWithBonus.String(),
	})
}
