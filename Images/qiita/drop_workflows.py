import qiita_db as qdb
import sys


def remove(self):
    # store for later, after table entry is dropped
    workflow_name = self.name

    def _get_workflow_id(name):
        with qdb.sql_connection.TRN:
            sql = """SELECT default_workflow_id
                     FROM qiita.default_workflow
                     WHERE name = %s"""
            qdb.sql_connection.TRN.add(sql, [name])
            return qdb.sql_connection.TRN.execute_fetchlast()
    def _get_node_ids(workflow_id):
        with qdb.sql_connection.TRN:
            sql = """SELECT default_workflow_node_id
                     FROM qiita.default_workflow_node
                     WHERE default_workflow_id = %s"""
            qdb.sql_connection.TRN.add(sql, [workflow_id])
            return qdb.sql_connection.TRN.execute_fetchflatten()
    def _get_edge_ids(node_ids):
        if len(node_ids) > 0:
            with qdb.sql_connection.TRN:
                sql = """SELECT default_workflow_edge_id
                         FROM qiita.default_workflow_edge
                         WHERE parent_id in %s OR child_id in %s"""
                qdb.sql_connection.TRN.add(sql, [tuple(node_ids), tuple(node_ids)])
                return qdb.sql_connection.TRN.execute_fetchflatten()
        else:
            return []

    workflow_id = _get_workflow_id(self.name)
    node_ids = _get_node_ids(workflow_id)
    edge_ids = _get_edge_ids(node_ids)
    with qdb.sql_connection.TRN:
        if len(edge_ids) > 0:
            sql = """DELETE FROM qiita.default_workflow_edge_connections
                     WHERE default_workflow_edge_id in %s"""
            qdb.sql_connection.TRN.add(sql, [tuple(edge_ids)])

            sql = """DELETE FROM qiita.default_workflow_edge
                     WHERE default_workflow_edge_id in %s"""
            qdb.sql_connection.TRN.add(sql, [tuple(edge_ids)])

        if workflow_id is not None:
            sql = """DELETE FROM qiita.default_workflow_node
                     WHERE default_workflow_id = %s"""
            qdb.sql_connection.TRN.add(sql, [workflow_id])

            sql = """DELETE FROM qiita.default_workflow_data_type
                     WHERE default_workflow_id = %s"""
            qdb.sql_connection.TRN.add(sql, [workflow_id])

            sql = """DELETE FROM qiita.default_workflow
                     WHERE default_workflow_id = %s"""
            qdb.sql_connection.TRN.add(sql, [workflow_id])
    print("removed workflow '%s': ID=%i with %i nodes and %i edges" % (workflow_name, workflow_id, len(node_ids), len(edge_ids)), file=sys.stderr)

def remove_workflows():
    for w in qdb.software.DefaultWorkflow.iter():
        w.remove = remove
        w.remove(w)


remove_workflows()
