import { useEffect, useMemo, useState } from "react";
import AddressAutocomplete from "./AddressAutocomplete";

function formatCpfCnpj(value) {
  const digits = String(value ?? "").replace(/\D/g, "");
  if (!digits) return "";
  if (digits.length <= 11) {
    const part1 = digits.slice(0, 3);
    const part2 = digits.slice(3, 6);
    const part3 = digits.slice(6, 9);
    const part4 = digits.slice(9, 11);
    let formatted = part1;
    if (part2) formatted += `.${part2}`;
    if (part3) formatted += `.${part3}`;
    if (part4) formatted += `-${part4}`;
    return formatted;
  }
  const part1 = digits.slice(0, 2);
  const part2 = digits.slice(2, 5);
  const part3 = digits.slice(5, 8);
  const part4 = digits.slice(8, 12);
  const part5 = digits.slice(12, 14);
  let formatted = part1;
  if (part2) formatted += `.${part2}`;
  if (part3) formatted += `.${part3}`;
  if (part4) formatted += `/${part4}`;
  if (part5) formatted += `-${part5}`;
  return formatted;
}

function formatDateBrFromIso(value) {
  if (!value) return "";
  if (/^\d{2}\/\d{2}\/\d{4}$/.test(value)) return value;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  const day = String(date.getDate()).padStart(2, "0");
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const year = String(date.getFullYear());
  return `${day}/${month}/${year}`;
}

function formatDateMask(value) {
  const digits = value.replace(/\D/g, "").slice(0, 8);
  const part1 = digits.slice(0, 2);
  const part2 = digits.slice(2, 4);
  const part3 = digits.slice(4, 8);
  let formatted = part1;
  if (part2) formatted += `/${part2}`;
  if (part3) formatted += `/${part3}`;
  return formatted;
}

function isValidDateBr(value) {
  if (!/^\d{2}\/\d{2}\/\d{4}$/.test(value)) return false;
  const [day, month, year] = value.split("/").map(Number);
  const date = new Date(year, month - 1, day);
  return (
    date.getFullYear() === year &&
    date.getMonth() === month - 1 &&
    date.getDate() === day
  );
}

function parseDateBrToIso(value) {
  if (!isValidDateBr(value)) return "";
  const [day, month, year] = value.split("/").map(Number);
  return `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

export default function FormField({
  label,
  type = "text",
  value,
  onChange,
  options = [],
  placeholder,
  className = "",
  disabled = false
}) {
  const fieldId = label ? label.toLowerCase().replace(/\s+/g, "-") : undefined;
  const fieldValue = value ?? "";

  const isDateBr = type === "date-br" || type === "date";
  const initialDate = useMemo(() => formatDateBrFromIso(fieldValue), [fieldValue]);
  const [dateInput, setDateInput] = useState(initialDate);

  useEffect(() => {
    if (!isDateBr) return;
    setDateInput(formatDateBrFromIso(fieldValue));
  }, [fieldValue, isDateBr]);

  if (type === "textarea") {
    return (
      <div className={`form-field ${className}`.trim()}>
        {label && <label htmlFor={fieldId}>{label}</label>}
        <textarea
          id={fieldId}
          value={fieldValue}
          placeholder={placeholder}
          disabled={disabled}
          onChange={(event) => onChange(event.target.value)}
        />
      </div>
    );
  }

  if (type === "select") {
    return (
      <div className={`form-field ${className}`.trim()}>
        {label && <label htmlFor={fieldId}>{label}</label>}
        <select
          id={fieldId}
          value={fieldValue}
          disabled={disabled}
          onChange={(event) => onChange(event.target.value)}
        >
          <option value="">Selecione</option>
          {options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </div>
    );
  }

  if (type === "checkbox") {
    return (
      <div className={`form-field ${className}`.trim()}>
        <label className="inline">
          <input
            type="checkbox"
            checked={Boolean(value)}
            disabled={disabled}
            onChange={(event) => onChange(event.target.checked)}
          />
          {label}
        </label>
      </div>
    );
  }

  if (type === "address") {
    return (
      <AddressAutocomplete
        label={label}
        value={fieldValue}
        placeholder={placeholder}
        className={className}
        disabled={disabled}
        onChange={onChange}
      />
    );
  }

  if (type === "document") {
    const formattedValue = formatCpfCnpj(fieldValue);
    return (
      <div className={`form-field ${className}`.trim()}>
        {label && <label htmlFor={fieldId}>{label}</label>}
        <input
          id={fieldId}
          type="text"
          value={formattedValue}
          placeholder={placeholder}
          inputMode="numeric"
          disabled={disabled}
          onChange={(event) => onChange(formatCpfCnpj(event.target.value))}
        />
      </div>
    );
  }

  if (isDateBr) {
    return (
      <div className={`form-field ${className}`.trim()}>
        {label && <label htmlFor={fieldId}>{label}</label>}
        <input
          id={fieldId}
          type="text"
          value={dateInput}
          placeholder={placeholder || "dd/mm/aaaa"}
          inputMode="numeric"
          disabled={disabled}
          onChange={(event) => {
            const masked = formatDateMask(event.target.value);
            setDateInput(masked);
            if (!masked) {
              onChange("");
              return;
            }
            if (isValidDateBr(masked)) {
              onChange(parseDateBrToIso(masked));
            }
          }}
        />
      </div>
    );
  }

  return (
    <div className={`form-field ${className}`.trim()}>
      {label && <label htmlFor={fieldId}>{label}</label>}
      <input
        id={fieldId}
        type={type}
        value={fieldValue}
        placeholder={placeholder}
        disabled={disabled}
        onChange={(event) => onChange(event.target.value)}
      />
    </div>
  );
}
