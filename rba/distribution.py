#!/usr/bin/python
#
# distribution.py - describes a general distribution
#
# Author:  epettis@google.com (Eddie Pettis)


class Distribution (object):
    """Describes probability distribution of a parameter."""
    def __init__(self):
        self._mean = 0
        self._variance = 0
        self._samples = []

    def mean(self):
        return self._mean

    def samples(self):
        return self._samples

    def variance(self):
        return self._variance

    def Add(self, other):
        """
        Adds two distibutions together.  You can no longer Append() of Extend()
        after performing this operation.  Because it will screw things up.
        To protect against this, we kill the functions.
        """
        self.Append = None
        self.Extend = None

        self._mean = self._mean + other.mean()
        self._variance = self._variance + other.variance()

    def Append(self, new_sample):
        self._samples.append(new_sample)
        self.ComputeMean()
        self.ComputeVariance()

    def ComputeMean(self):
        sum = 0
        if len(self._samples) == 0: return 0.0
        for s in self._samples:
            sum += s
        self._mean = sum / (len(self._samples)*1.0)
        return self._mean

    def ComputeVariance(self):
        if len(self._samples) == 0: return 0.0

        # May optimize this out later
        mean = self.ComputeMean()

        sum = 0
        for s in self._samples:
            sum += (s - mean)**2
        self._variance = sum / (len(self._samples)*1.0)

    def Extend(self, many_samples):
        self._samples.extend(many_samples)
        self.ComputeMean()
        self.ComputeVariance()

    def Join(self, other_gaussian):
        self._samples.extend(other_gaussian.samples())
        self.ComputeMean()
        self.ComputeVariance()

    def Subtract(self, other):
        """
        Adds two distibutions together.  You can no longer Append() of Extend()
        after performing this operation.  Because it will screw things up.
        To protect against this, we kill the functions.
        """
        self.Append = None
        self.Extend = None

        self._mean = self._mean - other.mean()
        self._variance = self._variance + other.variance()

