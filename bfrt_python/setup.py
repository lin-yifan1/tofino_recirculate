# insert one entry to the rec_num_table
# run with ./run_bfshell.sh -b ./setup.py -i

p4 = bfrt.recirculate.pipe

rec_num_table = p4.SwitchIngress.rec_num_table

rec_num_table.add_with_send(rec_num=0, port=1)

bfrt.complete_operations()

print ("Table rec_num_table:")
rec_num_table.dump(table=True)