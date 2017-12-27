BDIR=$(realpath  $(CTF_BUILD_DIR))
ifeq (,${BDIR})
  BDIR=$(shell pwd)
endif
export BDIR
export ODIR=$(BDIR)/obj
export OEDIR=$(BDIR)/obj_ext
include $(BDIR)/config.mk
export FCXX
export OFFLOAD_CXX
export LIBS

all: $(BDIR)/lib/libctf.a $(BDIR)/lib_shared/libctf.so


.PHONY: install
install: $(BDIR)/lib/libctf.a $(BDIR)/lib_shared/libctf.so
	if [ -d hptt ]; then  \
		echo "WARNING: detected HPTT installation in hptt/, you might need to also install it manually separately."; \
	fi 
	if [ -d scalapack ]; then \
		echo "WARNING: detected ScaLAPACK installation in scalapack/, you might need to also install it manually separately."; \
	fi 
	cp $(BDIR)/lib/libctf.a $(INSTALL_DIR)/lib 
	cp $(BDIR)/lib_shared/libctf.so $(INSTALL_DIR)/lib 
	sh src/scripts/expand_includes.sh
	mv include/ctf_all.hpp $(INSTALL_DIR)/include/ctf.hpp

.PHONY: uninstall
uninstall: 
	rm $(INSTALL_DIR)/lib/libctf.a 
	rm $(INSTALL_DIR)/lib/libctf.so 
	rm $(INSTALL_DIR)/include/ctf.hpp 


EXAMPLES = algebraic_multigrid apsp bitonic_sort btwn_central ccsd checkpoint dft_3D fft force_integration force_integration_sparse jacobi matmul neural_network particle_interaction qinformatics recursive_matmul scan sparse_mp3 sparse_permuted_slice spectral_element spmv sssp strassen trace mis mis2 ao_mo_transf 
TESTS = bivar_function bivar_transform ccsdt_map_test ccsdt_t3_to_t2 dft diag_ctr diag_sym endomorphism_cust endomorphism_cust_sp endomorphism gemm_4D multi_tsr_sym permute_multiworld readall_test readwrite_test repack scalar speye sptensor_sum subworld_gemm sy_times_ns test_suite univar_function weigh_4D  reduce_bcast

BENCHMARKS = bench_contraction bench_nosym_transp bench_redistribution model_trainer 

SCALAPACK_TESTS = nonsq_pgemm_test nonsq_pgemm_bench hosvd

STUDIES = fast_diagram fast_3mm fast_sym fast_sym_4D \
          fast_tensor_ctr fast_sy_as_as_tensor_ctr fast_as_as_sy_tensor_ctr

EXECUTABLES = $(EXAMPLES) $(TESTS) $(BENCHMARKS) $(SCALAPACK_TESTS) $(STUDIES) 

export EXAMPLES
export TESTS
export BENCHMARKS
export SCALAPACK_TESTS
export STUDIES



.PHONY: executables
executables: $(EXECUTABLES)
$(EXECUTABLES): $(BDIR)/lib/libctf.a


.PHONY: examples
examples: $(EXAMPLES)
$(EXAMPLES):
	$(MAKE) $@ -C examples

.PHONY: tests
tests: $(TESTS)
$(TESTS):
	$(MAKE) $@ -C test

.PHONY: scalapack_tests
scalapack_tests: $(SCALAPACK_TESTS)
$(SCALAPACK_TESTS):
	$(MAKE) $@ -C scalapack_tests

.PHONY: bench
bench: $(BENCHMARKS)
$(BENCHMARKS):
	$(MAKE) $@ -C bench

.PHONY: studies
studies: $(STUDIES)
$(STUDIES):
	$(MAKE) $@ -C studies

.PHONY: ctf_objs
ctf_objs:
	$(MAKE) ctf -C src; 

.PHONY: ctflib
ctflib: ctf_objs 
	$(AR) -crs $(BDIR)/lib/libctf.a $(ODIR)/*.o; 

ctf_ext_objs:
	$(MAKE) ctf_ext_objs -C src_python; 

.PHONY: shared
shared: ctflibso
.PHONY: ctflibso
ctflibso: export FCXX+=-fPIC
ctflibso: export OFFLOAD_CXX+=-fPIC
ctflibso: export ODIR=$(BDIR)/obj_shared
ctflibso: ctf_objs ctf_ext_objs
	$(FCXX) -shared -o $(BDIR)/lib_shared/libctf.so $(ODIR)/*.o $(OEDIR)/*.o  $(SO_LIB_PATH) $(SO_LIB_FILES) $(LDFLAGS)


PYTHON_SRC_FILES=src_python/ctf/core.pyx src_python/ctf/random.pyx

.PHONY: python
python: $(BDIR)/setup.py $(BDIR)/lib_shared/libctf.so $(PYTHON_SRC_FILES)
	cd src_python; \
	ln -sf $(BDIR)/setup.py setup.py; \
	LDFLAGS="-L$(BDIR)/lib_shared" python setup.py build_ext -b $(BDIR)/lib_python/ -t $(BDIR)/obj_shared/; \
	rm setup.py; \
	cd ..; \
	cp src_python/ctf/__init__.py $(BDIR)/lib_python/ctf/__init__.py


.PHONY: python_install
python_install: install pip
.PHONY: pip
pip: $(BDIR)/setup.py $(BDIR)/lib_shared/libctf.so $(PYTHON_SRC_FILES) 
	cd src_python; \
	ln -sf $(BDIR)/setup.py setup.py; \
	pip install -b $(BDIR)/lib_python/ -t $(BDIR)/obj_shared/ . --upgrade; \
	rm setup.py; \
	cd .. 

.PHONY: python_uninstall
python_uninstall:
	pip uninstall ctf

.PHONY: test_python
test_python: python
	LD_LIBRARY_PATH="$(LD_LIBRARY_PATH):$(BDIR)/lib_shared:$(BDIR)/lib_python:$(LD_LIB_PATH)" PYTHONPATH="$(PYTHONPATH):$(BDIR)/lib_python" python ./test/python/test_base.py

.PHONY: test_python2
test_python2: python
	LD_LIBRARY_PATH="$(LD_LIBRARY_PATH):$(BDIR)/lib_shared:$(BDIR)/lib_python:$(LD_LIB_PATH)" PYTHONPATH="$(PYTHONPATH):$(BDIR)/lib_python" mpirun -np 2 python ./test/python/test_base.py

.PHONY: test_einsum
test_einsum: python
	LD_LIBRARY_PATH="$(LD_LIBRARY_PATH):$(BDIR)/lib_shared:$(BDIR)/lib_python:$(LD_LIB_PATH)" PYTHONPATH="$(PYTHONPATH):$(BDIR)/lib_python" python ./test/python/test_einsum.py

.PHONY: test_new
test_new: python
	LD_LIBRARY_PATH="$(LD_LIBRARY_PATH):$(BDIR)/lib_shared:$(BDIR)/lib_python:$(LD_LIB_PATH)" PYTHONPATH="$(PYTHONPATH):$(BDIR)/lib_python" python ./test/python/test_new.py

.PHONY: test_base
test_base: python
	LD_LIBRARY_PATH="$(LD_LIBRARY_PATH):$(BDIR)/lib_shared:$(BDIR)/lib_python:$(LD_LIB_PATH)" PYTHONPATH="$(PYTHONPATH):$(BDIR)/lib_python" python ./test/python/test_base.py

.PHONY: test_get_item
test_get_item: python
	LD_LIBRARY_PATH="$(LD_LIBRARY_PATH):$(BDIR)/lib_shared:$(BDIR)/lib_python:$(LD_LIB_PATH)" PYTHONPATH="$(PYTHONPATH):$(BDIR)/lib_python" python ./test/python/test_get_item.py

.PHONY: test_live
test_live: python
	LD_LIBRARY_PATH="$(LD_LIBRARY_PATH):$(BDIR)/lib_shared:$(BDIR)/lib_python:$(LD_LIB_PATH)" PYTHONPATH="$(PYTHONPATH):$(BDIR)/lib_python" ipython -i -c "import numpy as np; import ctf"

$(BDIR)/lib/libctf.a: src/*/*.cu src/*/*.cxx src/*/*.h Makefile src/Makefile src/*/Makefile $(BDIR)/config.mk
	$(MAKE) ctflib

$(BDIR)/lib_shared/libctf.so: src/*/*.cu src/*/*.cxx src/*/*.h Makefile src/Makefile src/*/Makefile $(BDIR)/config.mk
	$(MAKE) ctflibso
	
clean: clean_bin clean_lib clean_obj clean_py


test: test_suite
	$(BDIR)/bin/test_suite

test2: test_suite
	mpirun -np 2 $(BDIR)/bin/test_suite

test3: test_suite
	mpirun -np 3 $(BDIR)/bin/test_suite

test4: test_suite
	mpirun -np 4 $(BDIR)/bin/test_suite

test6: test_suite
	mpirun -np 6 $(BDIR)/bin/test_suite

test7: test_suite
	mpirun -np 7 $(BDIR)/bin/test_suite

test8: test_suite
	mpirun -np 8 $(BDIR)/bin/test_suite

clean_py:
	rm -f $(BDIR)/src_python/ctf/core.*.so
	rm -f $(BDIR)/src_python/ctf/random.*.so
	rm -f $(BDIR)/src_python/ctf/core.cpp
	rm -f $(BDIR)/src_python/ctf/random.cpp
	rm -rf $(BDIR)/src_python/build
	rm -rf $(BDIR)/src_python/__pycache__
	rm -f $(BDIR)/lib_python/ctf/core.*.so
	rm -f $(BDIR)/lib_python/ctf/random.*.so


clean_bin:
	for comp in $(EXECUTABLES) ; do \
		rm -f $(BDIR)/bin/$$comp ; \
	done 

clean_lib:
	rm -f $(BDIR)/lib/libctf.a
	rm -f $(BDIR)/lib_shared/libctf.so
	rm -f $(BDIR)/lib_shared/libctf_ext.so

clean_obj:
	rm -f $(BDIR)/obj/*.o 
	rm -f $(BDIR)/obj_ext/*.o 
	rm -f $(BDIR)/obj_shared/*.o 
	rm -rf $(BDIR)/obj_shared/ctf/ 
	rm -f $(BDIR)/build/*/*/*.o 
