import { useEffect, useRef, useState } from "react";

const apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;

function loadGoogleMaps() {
  if (!apiKey) return Promise.resolve(null);
  if (window.__googleMapsPromise) return window.__googleMapsPromise;

  window.__googleMapsPromise = new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = `https://maps.googleapis.com/maps/api/js?key=${apiKey}&libraries=places`;
    script.async = true;
    script.onload = () => resolve(window.google);
    script.onerror = () => reject(new Error("Falha ao carregar o Google Maps"));
    document.body.appendChild(script);
  });

  return window.__googleMapsPromise;
}

export default function AddressAutocomplete({
  label,
  value,
  onChange,
  placeholder,
  className = "",
  disabled = false
}) {
  const [ready, setReady] = useState(false);
  const [suggestions, setSuggestions] = useState([]);
  const serviceRef = useRef(null);
  const debounceRef = useRef(null);

  useEffect(() => {
    if (!apiKey) return;
    let isMounted = true;

    loadGoogleMaps()
      .then(() => {
        if (!isMounted) return;
        if (window.google?.maps?.places) {
          serviceRef.current = new window.google.maps.places.AutocompleteService();
          setReady(true);
        }
      })
      .catch(() => {
        if (isMounted) setReady(false);
      });

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    if (!ready || !serviceRef.current || disabled) return;
    const input = (value || "").trim();
    if (!input || input.length < 3) {
      setSuggestions([]);
      return;
    }

    clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      serviceRef.current.getPlacePredictions(
        {
          input,
          types: ["address"],
          componentRestrictions: { country: "br" }
        },
        (predictions, status) => {
          if (status !== window.google.maps.places.PlacesServiceStatus.OK) {
            setSuggestions([]);
            return;
          }
          setSuggestions(predictions || []);
        }
      );
    }, 250);

    return () => clearTimeout(debounceRef.current);
  }, [value, ready, disabled]);

  return (
    <div className={`form-field address-field ${className}`.trim()}>
      {label && <label>{label}</label>}
      <input
        type="text"
        value={value || ""}
        placeholder={placeholder}
        autoComplete="off"
        disabled={disabled}
        onChange={(event) => onChange(event.target.value)}
      />
      {apiKey && suggestions.length > 0 && !disabled && (
        <div className="autocomplete-list">
          {suggestions.map((item) => (
            <button
              key={item.place_id}
              type="button"
              className="autocomplete-item"
              onClick={() => {
                onChange(item.description);
                setSuggestions([]);
              }}
            >
              {item.description}
            </button>
          ))}
        </div>
      )}
      {!apiKey && (
        <small className="muted">Configure a chave do Google Maps para sugestões.</small>
      )}
    </div>
  );
}
