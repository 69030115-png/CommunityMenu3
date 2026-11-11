"""Integration tests. Use ONLY a disposable database named community_menu_test_*.
Run: DB_NAME=community_menu_test_demo python -m unittest -v test_logic
The test database must already exist. It is cleared before every test.
"""
import os
import unittest
from datetime import date, timedelta
import db
import logic
import ai_helper
from mysql_compat import bind_sql


class BindTests(unittest.TestCase):
    def test_literals_and_parameters(self):
        self.assertEqual(bind_sql("SELECT '?' AS x, :item, ? -- ?\n"),
                         "SELECT '?' AS x, %(item)s, %s -- ?\n")


@unittest.skipUnless(db.DB_CONFIG['database'].startswith('community_menu_test_'),
                     'Requires an isolated community_menu_test_* database')
class IntegrationTests(unittest.TestCase):
    def setUp(self):
        with db.get_conn() as conn:
            conn.execute('DROP TRIGGER IF EXISTS trg_movement_after_insert')
            conn.execute('SET FOREIGN_KEY_CHECKS=0')
            for name in ['po_items','purchase_orders','plan_items','menu_plans',
                         'produce','farmers','recipe_items','menus','movements','lots','ingredients']:
                conn.execute('DROP TABLE IF EXISTS ' + name)
            conn.execute('SET FOREIGN_KEY_CHECKS=1')
        db.init_db()
        self.ing = logic.list_ingredients()[0]
        self.menu = logic.list_menus()[0]
        self.farmer = logic.list_farmers()[0]

    def test_read_views_and_ai_data(self):
        self.assertEqual(len(logic.list_ingredients()), 20)
        self.assertEqual(len(logic.list_menus()), 10)
        self.assertEqual(len(logic.list_farmers()), 5)
        logic.dashboard()
        logic.list_produce()
        logic.list_pos()
        logic.report('2000-01-01', '2099-12-31')
        self.assertEqual(len(ai_helper.build_prompt_data(500, 5, [])['menus']), 10)
        result = ai_helper.check_answer('{"recommendations":[{"menu_code":"M01","reason":"test"}]}')
        self.assertEqual(result[0][0]['code'], 'M01')
        lot = logic.list_lots(self.ing['id'])[0]
        date.fromisoformat(lot['use_by'])

    def test_stock_changes_exactly_once_and_rollback(self):
        iid = self.ing['id']
        before = logic.get_ingredient(iid)
        total = logic.list_ingredients()[0]['stock']
        logic.receive_manual(iid, 10.5, 1.25, '2099-12-31', 'test')
        self.assertAlmostEqual(logic.list_ingredients()[0]['stock'], total+10.5)
        logic.issue_manual(iid, 2.25, 'USE', 'test')
        self.assertAlmostEqual(logic.list_ingredients()[0]['stock'], total+8.25)
        lot = logic.list_lots(iid)[0]
        logic.waste_lot(lot['id'], 1.5, 'test')
        self.assertAlmostEqual(logic.list_ingredients()[0]['stock'], total+6.75)
        logic.adjust_lot(lot['id'], 50.25, 'count')
        self.assertEqual(next(x for x in logic.list_lots(iid) if x['id']==lot['id'])['qty_left'],50.25)
        saved = logic.list_ingredients()[0]['stock']
        with self.assertRaises(logic.AppError):
            logic.issue_manual(iid, 1e9, 'USE', 'test')
        self.assertEqual(logic.list_ingredients()[0]['stock'], saved)
        self.assertGreater(len(logic.list_movements(iid)), 1)

    def test_edit_ingredients_recipes_and_community(self):
        i=self.ing
        logic.save_ingredient(i['id'],i['code'],i['name'],i['unit'],100.5,10)
        with self.assertRaises(logic.AppError):
            logic.save_ingredient(i['id'],i['code'],i['name'],'ชิ้น',100,10)
        logic.save_ingredient(None,'TEST','Test ingredient','กรัม',1.5,7)
        mid=logic.save_menu(None,'TEST','Test menu',[(i['id'],1.25)])
        self.assertEqual(logic.get_recipe(mid)[0]['qty_per_dish'],1.25)
        logic.save_menu(mid,'TEST','Edited',[(i['id'],2.5)])
        logic.save_farmer(None,'Test farmer','Test area','000')
        fid=logic.list_farmers()[-1]['id']
        logic.save_farmer(fid,'Edited farmer','Area','000')
        logic.save_produce(None,fid,i['id'],12.5,'กก.',1.5,date.today().isoformat())
        produce=next(x for x in logic.list_produce() if x['farmer_id']==fid)
        logic.save_produce(produce['id'],fid,i['id'],13.5,'กก.',2.5,date.today().isoformat())

    def test_plan_and_purchase_lifecycle(self):
        items=[(self.menu['id'],1)]
        lines, summary=logic.calc_plan(items)
        self.assertGreater(summary['total_cost'],0)
        pid=logic.create_plan(items,500.0)
        self.assertIn(self.menu['name'],logic.list_plans()[0]['menus'])
        self.assertEqual(logic.get_plan_items(pid),items)
        logic.use_plan(pid)
        with self.assertRaises(logic.AppError):
            logic.use_plan(pid)
        iid=self.ing['id']
        total=logic.list_ingredients()[0]['stock']
        po=logic.create_po(self.farmer['id'],[(iid,3.5,1.25)],pid)
        self.assertEqual(logic.get_po_items(po)[0]['qty'],3.5)
        logic.receive_po(po)
        self.assertAlmostEqual(logic.list_ingredients()[0]['stock'],total+3.5)
        with self.assertRaises(logic.AppError):
            logic.receive_po(po)
        cancelled=logic.create_po(self.farmer['id'],[(iid,1,1)])
        logic.cancel_po(cancelled)
        self.assertEqual(logic.list_pos('CANCELLED')[0]['id'],cancelled)
        logic.report('2000-01-01','2099-12-31')

    def test_old_trigger_migration(self):
        with db.get_conn() as conn:
            conn.execute('''CREATE TRIGGER trg_movement_after_insert AFTER INSERT ON movements
                            FOR EACH ROW UPDATE lots SET qty_left=qty_left+NEW.qty WHERE id=NEW.lot_id''')
        db.init_db()
        total=logic.list_ingredients()[0]['stock']
        logic.receive_manual(self.ing['id'],5,1,'2099-12-31','migration')
        self.assertEqual(logic.list_ingredients()[0]['stock'],total+5)


if __name__ == '__main__':
    unittest.main()
