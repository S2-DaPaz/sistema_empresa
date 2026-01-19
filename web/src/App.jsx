import { Routes, Route } from "react-router-dom";
import Layout from "./components/Layout";
import Dashboard from "./pages/Dashboard";
import Clients from "./pages/Clients";
import Tasks from "./pages/Tasks";
import TaskDetail from "./pages/TaskDetail";
import Templates from "./pages/Templates";
import Budgets from "./pages/Budgets";
import Users from "./pages/Users";
import Products from "./pages/Products";
import TaskTypes from "./pages/TaskTypes";
import NotFound from "./pages/NotFound";

export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
      <Route index element={<Dashboard />} />
      <Route path="/clientes" element={<Clients />} />
      <Route path="/tarefas" element={<Tasks />} />
      <Route path="/tarefas/nova" element={<TaskDetail />} />
      <Route path="/tarefas/:id" element={<TaskDetail />} />
      <Route path="/modelos" element={<Templates />} />
        <Route path="/orcamentos" element={<Budgets />} />
        <Route path="/usuarios" element={<Users />} />
        <Route path="/produtos" element={<Products />} />
        <Route path="/tipos-tarefa" element={<TaskTypes />} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  );
}
