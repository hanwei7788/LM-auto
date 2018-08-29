#!/usr/bin/env python3

# To use as a module, just call gen_graph_data to generate the data, and pass
# that as a parameter to plot_data; that's where the main functionality of this
# module resides

import sys
import argparse
import itertools
import matplotlib.pyplot as pyplot

# Defines how many places a value is offset in the CSV from its name (eg.
# uboot2kernel could be given as "uboot2kernel,12345,1000,12345" where 1000
# is the actual measurement value and the rest of the values are something
# nonrelevant
TIME_VALUE_OFFSET = 2

# For command line use: Default size of the graph picture
GRAPH_DEFAULT_WID = 800
GRAPH_DEFAULT_HEI = 600

cmdline_args = [
	(("--outfile", "-o"), {"required": True}),
	(("--measurements", "-m"), {"required": True,
	                            "help": "a list of measurement names separated by spaces"}),
	(("--width", "-x"), {"type": int,
	                     "help": "graph picture width",
	                     "default": GRAPH_DEFAULT_WID}),
	(("--height", "-y"), {"type": int,
	                      "help": "graph picture height",
	                      "default": GRAPH_DEFAULT_HEI}),
	(("files",), {"nargs": "+", "help": "<csv file>:<image name>"})
]

class CSVError(Exception):
	pass

# A class to hold a table with named rows and columns. This design is used
# instead of using dicts for rows and columns to preserve row and column order
class DataTable():
	def __init__(self, rows, cols):
		self.rows = rows
		self.cols = cols

		self.table = []
		for _ in rows:
			self.table.append([None] * len(cols))

	def __getitem__(self, key):
		row, col = key
		rowindex, colindex = self._generate_index(row, col)
		return self.table[rowindex][colindex]

	def __setitem__(self, key, value):
		row, col = key
		rowindex, colindex = self._generate_index(row, col)
		self.table[rowindex][colindex] = value

	def _generate_index(self, row, col):
		rowindex = self.rows.index(row)
		colindex = self.cols.index(col)
		return (rowindex, colindex)

	def prettyprint(self):
		return "rows: %s\ncols: %s\n\n%s" % \
		       (self.rows,
		        self.cols,
		        "\n".join([str(row) for row in self.table]))

	def get_row(self, row):
		rowindex = self.rows.index(row)
		return self.table[rowindex]

def read_csv(fname, separator = ","):
	result = []
	with open(fname, "r") as f:
		for line_with_newline in f:
			line = line_with_newline.rstrip()
			if (line == ""):
				continue

			atoms = line.split(separator)
			result.append(atoms)
	return result

def sufu_csv_data_from_row(row, col):
	try:
		name_col = row.index(col)
		found = row[name_col + TIME_VALUE_OFFSET]
	except ValueError as e:
		raise CSVError("No column %s found on line %s" %
		               (col, ",".join(row))) from None
	except IndexError as e:
		raise CSVError("No value for item %s on line %s" %
		               (col, ",".join(row))) from None

	try:
		return int(found)
	except ValueError:
		raise CSVError("Nonnumeric value for item %s" %
		               col) from None
	
def csv_get_col(col, data):
	result = []
	for row in data:
		if (row == []):
			continue

		try:
			atom = sufu_csv_data_from_row(row, col)
			result.append(atom)
		except CSVError:
			pass

	if (result == []):
		raise CSVError("Column %s missing from some CSV file(s)" % col)
	else:
		return result

# infiles ought to be sorted according to the order that you want the images
# to appear on the graph
# Returns a DataTable that can be fed directly to plot_data()
def gen_graph_data(infiles, wanted_measurements):
	image_names = [infile[0] for infile in infiles]
	graph_data = DataTable(wanted_measurements, image_names)

	for image_name, fname in infiles:
		csv = read_csv(fname)
		for measurement in wanted_measurements:
			times = csv_get_col(measurement, csv)
			mean = sum(times) / len(times)
			graph_data[measurement, image_name] = mean
	return graph_data

# Take a list of aliases for image names, separate them by a separator, and
# combine all atoms that are common to each one of them together (ie. reduce
# away all redundant parts of the names).
#
# Returns a tuple: (common part, [alias1_reduced, alias2_reduced, ...])
def reduce_aliases(image_names, atom_separator = "-"):

	# Using None here to mark an inexistent atom, in case the image names
	# are of different length in atoms. This is correct because None can
	# never be the result of split(); every subatom of list_of_lists must
	# be a str.
	def nth_atoms(list_of_lists, n):
		return [l[n] if len(l) > n else None for l in list_of_lists]

	# Absolutely genius! Taken from:
	# https://docs.python.org/3/library/itertools.html#itertools-recipes
	def all_equal(atoms):
		g = itertools.groupby(atoms)
		return next(g, True) and not next(g, False)

	def add_unique_part(reduced_aliases, unique_atoms):
		for reduced_alias, atom in zip(reduced_aliases, unique_atoms):
			if (atom is not None):
				reduced_alias.append(atom)

	aliases = [name.split(atom_separator) for name in image_names]
	max_alias_len = max(len(alias) for alias in aliases)
	reduced_aliases = [list() for _ in range(len(aliases))]
	common_parts = []

	for i in range(max_alias_len):
		nths = nth_atoms(aliases, i)
		if (all_equal(nths)):
			common_parts.append(nths[0])
		else:
			add_unique_part(reduced_aliases, nths)

	common = atom_separator.join(common_parts)
	unique = [atom_separator.join(atoms) for atoms in reduced_aliases]

	return (common, unique)

def gen_plot_size(w, h, dpi = 100):
	w_in = w / dpi
	h_in = h / dpi
	return {"figsize": (w_in, h_in), "dpi": dpi}

def plot_data(outfile, data, graph_wid, graph_hei):
	image_names = data.cols
	name_common_part, imgname_unique_parts = reduce_aliases(image_names)

	xindices = range(len(image_names))
	fig = pyplot.figure(**gen_plot_size(graph_wid, graph_hei))
	ax = fig.add_subplot(111)
	ax.grid()

	for measurement in data.rows:
		image_times = data.get_row(measurement)
		ax.plot(xindices, image_times, label=measurement, marker="o")
		for x, y in zip(xindices, image_times):
			text = str(round(y))
			ax.annotate(text,
			            (x, y),
			            xytext=(x, y),
			            ha="center",
			            va="bottom")

	ax.set_xlim(xmin=0, xmax=None)
	ax.set_ylim(ymin=0, ymax=None)
	ax.set(xlabel="Image", ylabel="Time (ms)")
	ax.set(title=name_common_part)

	ax.set_xticks(xindices)
	ax.set_xticklabels(imgname_unique_parts, rotation=90)

	legend = ax.legend(*ax.get_legend_handles_labels(),
	                   loc="lower center",
	                   bbox_to_anchor=(0.5, 1.05),
	                   ncol=len(data.rows))

	fig.savefig(outfile, bbox_extra_artists=(legend,), bbox_inches="tight")

def parse_file_list(cmdline_files):
	files = []
	for cmdline_file in cmdline_files:
		file_atoms = cmdline_file.split(":")
		fname = file_atoms[0]

		if (len(file_atoms) > 1 and file_atoms[1] != ""):
			alias = file_atoms[1]
		else:
			alias = fname

		files.append((alias, fname))
	return files

def cmdline_get_args(argv, arg_list):
	parser = argparse.ArgumentParser()
	for arg, params in arg_list:
		parser.add_argument(*arg, **params)

	result = parser.parse_args(argv[1:])

	result.files = parse_file_list(result.files)
	result.measurements = result.measurements.split(" ")
	return result

def main(argv):
	args = cmdline_get_args(argv, cmdline_args)
	wid = args.width
	hei = args.height
	measurements = args.measurements
	outfile = args.outfile
	imgs = args.files

	try:
		graph_data = gen_graph_data(imgs, measurements)
		plot_data(outfile, graph_data, wid, hei)
	except (FileNotFoundError, CSVError) as e:
		print(e, file=sys.stderr)

if (__name__ == "__main__"):
	sys.exit(main(sys.argv))
