import { Route, Routes } from "react-router-dom";
import Layout from "../../components/Layout";
import { RequireAdmin, RequireAuth, RequirePermission } from "../../components/AuthGate";
import Dashboard from "../../pages/Dashboard";
import Clients from "../../pages/Clients";
import Tasks from "../../pages/Tasks";
import TaskDetail from "../../pages/TaskDetail";
import Templates from "../../pages/Templates";
import Budgets from "../../pages/Budgets";
import Users from "../../pages/Users";
import Products from "../../pages/Products";
import TaskTypes from "../../pages/TaskTypes";
import Equipments from "../../pages/Equipments";
import ErrorLogs from "../../pages/admin/ErrorLogs";
import EventLogs from "../../pages/admin/EventLogs";
import Login from "../../pages/Login";
import NotFound from "../../pages/NotFound";
import { PERMISSIONS } from "../providers/AuthProvider";

export function AppRouter() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route element={<RequireAuth />}>
        <Route element={<Layout />}>
          <Route index element={<Dashboard />} />
          <Route path="/clientes" element={<Clients />} />
          <Route path="/tarefas" element={<Tasks />} />
          <Route path="/tarefas/nova" element={<TaskDetail />} />
          <Route path="/tarefas/:id" element={<TaskDetail />} />
          <Route path="/modelos" element={<Templates />} />
          <Route path="/orcamentos" element={<Budgets />} />
          <Route path="/equipamentos" element={<Equipments />} />
          <Route
            path="/usuarios"
            element={
              <RequirePermission permission={PERMISSIONS.VIEW_USERS}>
                <Users />
              </RequirePermission>
            }
          />
          <Route path="/produtos" element={<Products />} />
          <Route path="/tipos-tarefa" element={<TaskTypes />} />
          <Route
            path="/admin/logs-erros"
            element={
              <RequireAdmin>
                <ErrorLogs />
              </RequireAdmin>
            }
          />
          <Route
            path="/admin/logs-eventos"
            element={
              <RequireAdmin>
                <EventLogs />
              </RequireAdmin>
            }
          />
          <Route path="*" element={<NotFound />} />
        </Route>
      </Route>
    </Routes>
  );
}
