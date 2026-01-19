import { Link } from "react-router-dom";

export default function NotFound() {
  return (
    <section className="section">
      <div className="section-header">
        <h2 className="section-title">Página não encontrada</h2>
      </div>
      <p className="muted">Revise o endereço e tente novamente.</p>
      <Link className="btn secondary" to="/">
        Voltar ao painel
      </Link>
    </section>
  );
}
